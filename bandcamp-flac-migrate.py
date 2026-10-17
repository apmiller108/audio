#!/usr/bin/env python3
"""Replace Bandcamp MP3s in the Mixxx library with FLACs downloaded by bandcampsync.

Each matched MP3 is swapped for its FLAC in place (same folder, same name,
.flac extension) and the Mixxx track row is re-pointed at the new file, so the
track id -- and with it play history, playlists, crates, rating and cues --
stays the same.

Dry run by default: prints a summary and writes a TSV report. Pass --apply to
make changes (Mixxx must be closed).

Per migrated track:
  * FLAC is copied from the staging folder next to the MP3, and the Mixxx DB
    tags (the source of truth) are written into it.
  * MP3 is moved to the archive folder, keeping its path relative to ~/Music.
  * library/track_locations rows are updated; source_synchronized_ms is set to
    the FLAC's mtime so Mixxx doesn't re-import the file's tags over the DB.
  * Cue positions (stored as sample counts) are rescaled if the sample rate
    changed.
  * Beatgrids are cleared so Mixxx re-analyzes them, except BPM-locked grids,
    which are kept and rescaled. --keep-grids rescales all grids instead.
  * Waveforms are deleted so Mixxx regenerates them.
  * The track is added to a crate so it's easy to batch-analyze.
  * Hidden tracks are never touched.
"""

import argparse
import concurrent.futures
import csv
import datetime
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import unicodedata
from pathlib import Path

HOME = Path.home()
DURATION_TOLERANCE_S = 1.0
CRATE_NAME = "Bandcamp FLAC migrated"

# bandcampsync strips these characters and NFKD-normalizes file and folder names.
BANDCAMPSYNC_STRIPPED = set("\"#%'*/?\\`:")

# Vorbis comment fields written from the Mixxx DB, matching the names Mixxx
# itself writes (src/track/taglib/trackmetadata_xiph.cpp). Alternates are
# removed so no stale value lingers.
TAG_FIELDS = {
    "TITLE": "title",
    "ARTIST": "artist",
    "ALBUM": "album",
    "ALBUMARTIST": "album_artist",
    "GENRE": "genre",
    "COMMENT": "comment",
    "DATE": "year",
    "COMPOSER": "composer",
    "GROUPING": "grouping",
    "TRACKNUMBER": "tracknumber",
    "TRACKTOTAL": "tracktotal",
    "INITIALKEY": "key",
    "BPM": "bpm",
}
TAG_ALTERNATES = ["DESCRIPTION", "TOTALTRACKS", "ALBUM_ARTIST", "ALBUM ARTIST", "KEY", "TEMPO"]


def norm(name):
    name = unicodedata.normalize("NFKD", name)
    # Bandcamp's own file names turn brackets and colons into "-" ("[MOL051D]"
    # -> "-MOL051D-") while bandcampsync's folder names keep them or drop them,
    # so compare all of those as plain spaces.
    name = "".join(" " if c in "-[]" else c for c in name if c not in BANDCAMPSYNC_STRIPPED)
    return " ".join(name.casefold().split())


def load_pairs(path):
    """Explicit MP3 -> FLAC pairs for names that don't match: "mp3<TAB>flac" per line."""
    pairs = {}
    if path:
        for line in path.read_text().splitlines():
            if line.strip() and not line.startswith("#"):
                mp3, flac = line.split("\t")
                pairs[str(Path(mp3).expanduser())] = Path(flac).expanduser()
    return pairs


def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams",
         "-select_streams", "a:0", str(path)],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        return None
    data = json.loads(out.stdout)
    fmt, streams = data.get("format", {}), data.get("streams", [])
    if not streams:
        return None
    s = streams[0]
    tags = {k.upper(): v for k, v in fmt.get("tags", {}).items()}
    return {
        "duration": float(fmt.get("duration", 0)),
        "samplerate": int(s.get("sample_rate", 0)),
        "channels": int(s.get("channels", 0)),
        "bits": int(s.get("bits_per_raw_sample") or 0),
        "bitrate": int(fmt.get("bit_rate", 0)) // 1000,
        "tags": tags,
    }


def probe_all(paths):
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        return dict(zip(paths, pool.map(probe, paths)))


# --- Minimal protobuf rewriting for Mixxx beats blobs (src/proto/beats.proto) ---
# BeatGrid { Bpm bpm = 1; Beat first_beat = 2; }  BeatMap { repeated Beat beat = 1; }
# Beat { int32 frame_position = 1; ... }

def _read_varint(buf, i):
    shift = result = 0
    while True:
        b = buf[i]
        i += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, i
        shift += 7


def _varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def _parse(buf):
    fields, i = [], 0
    while i < len(buf):
        key, i = _read_varint(buf, i)
        num, wt = key >> 3, key & 7
        if wt == 0:
            val, i = _read_varint(buf, i)
        elif wt == 1:
            val, i = buf[i:i + 8], i + 8
        elif wt == 2:
            n, i = _read_varint(buf, i)
            val, i = buf[i:i + n], i + n
        elif wt == 5:
            val, i = buf[i:i + 4], i + 4
        else:
            raise ValueError(f"unsupported wire type {wt}")
        fields.append((num, wt, val))
    return fields


def _serialize(fields):
    out = bytearray()
    for num, wt, val in fields:
        out += _varint(num << 3 | wt)
        if wt == 0:
            out += _varint(val)
        elif wt == 2:
            out += _varint(len(val)) + val
        else:
            out += val
    return bytes(out)


def _rescale_beat(buf, ratio):
    fields = []
    for num, wt, val in _parse(buf):
        if num == 1 and wt == 0:
            pos = val - (1 << 64) if val >= 1 << 63 else val
            pos = round(pos * ratio)
            val = pos + (1 << 64) if pos < 0 else pos
        fields.append((num, wt, val))
    return _serialize(fields)


def rescale_beats(version, blob, ratio):
    if version.startswith("BeatGrid"):
        beat_field = 2
    elif version.startswith("BeatMap"):
        beat_field = 1
    else:
        raise ValueError(f"unknown beats version {version}")
    return _serialize([
        (num, wt, _rescale_beat(val, ratio) if num == beat_field and wt == 2 else val)
        for num, wt, val in _parse(blob)
    ])


# --- Indexing and matching ---

def index_flacs(flac_dir):
    flacs = sorted(flac_dir.rglob("*.flac"))
    print(f"Probing {len(flacs)} FLACs in {flac_dir} ...", file=sys.stderr)
    info = probe_all(flacs)
    by_key = {"name": {}, "folder": {}, "tags": {}}
    for f in flacs:
        if info[f] is None:
            continue
        by_key["name"].setdefault(norm(f.stem), []).append(f)
        # Single-track purchases are saved as <band>/<title>/<url-slug>.flac,
        # so the slug won't match an "Artist - Title.mp3" name; use the folders.
        if len(list(f.parent.glob("*.flac"))) == 1:
            title = re.sub(r" \[\d+\]$", "", f.parent.name)
            by_key["folder"].setdefault(norm(f"{f.parent.parent.name} - {title}"), []).append(f)
        tags = info[f]["tags"]
        if tags.get("ARTIST") and tags.get("TITLE"):
            by_key["tags"].setdefault(norm(f"{tags['ARTIST']} - {tags['TITLE']}"), []).append(f)
    return flacs, info, by_key


def load_mixxx_mp3s(db, music_dir):
    db.row_factory = sqlite3.Row
    rows = db.execute(
        """select l.*, t.id as loc_id, t.location as path, t.fs_deleted,
                  (select count(*) from cues c where c.track_id = l.id and c.type = 1) as hotcues
           from library l join track_locations t on l.location = t.id
           where t.location like ? and lower(t.location) like '%.mp3'""",
        (str(music_dir) + "/%",),
    ).fetchall()
    return [r for r in rows if not r["fs_deleted"]]


def is_bandcamp_evidence(row, mp3_info):
    comments = [row["comment"] or ""]
    if mp3_info:
        comments.append(mp3_info["tags"].get("COMMENT", ""))
    return any("bandcamp.com" in c.lower() for c in comments) or "bandcamp" in row["path"].lower()


def plan(args, db):
    flacs, flac_info, by_key = index_flacs(args.flac_dir)
    rows = load_mixxx_mp3s(db, args.music_dir)

    pairs = load_pairs(args.pairs)
    for flac in pairs.values():
        if flac not in flac_info:
            sys.exit(f"Paired FLAC not found under {args.flac_dir}: {flac}")

    candidates = []
    for row in rows:
        if row["path"] in pairs:
            candidates.append((row, "manual", [pairs.pop(row["path"])]))
            continue
        key = norm(Path(row["path"]).stem)
        for method in ("name", "folder", "tags"):
            hits = by_key[method].get(key, [])
            if hits:
                candidates.append((row, method, hits))
                break
    # Pairs migrated by an earlier run have their FLAC in place and the MP3 gone.
    missing = [mp3 for mp3 in pairs if not (Path(mp3).with_suffix(".flac").exists() and not Path(mp3).exists())]
    if missing:
        sys.exit("Paired MP3s not found in the Mixxx library:\n  " + "\n  ".join(missing))

    print(f"Probing {len(candidates)} matched MP3s ...", file=sys.stderr)
    mp3_info = probe_all([Path(r["path"]) for r, _, _ in candidates])

    flac_users = {}
    for row, method, hits in candidates:
        if len(hits) == 1:
            flac_users.setdefault(hits[0], []).append(row["id"])

    entries, used = [], set()
    for row, method, hits in candidates:
        mp3 = Path(row["path"])
        m_info = mp3_info[mp3]
        e = {
            "status": "", "track_id": row["id"], "method": method, "mp3": str(mp3),
            "flac_src": str(hits[0]) if len(hits) == 1 else " | ".join(map(str, hits)),
            "target": str(mp3.with_suffix(".flac")), "duration_diff": "",
            "mp3_rate": row["samplerate"], "flac_rate": "", "flac_bits": "",
            "bpm_locked": row["bpm_lock"], "hotcues": row["hotcues"],
            "timesplayed": row["timesplayed"], "note": "",
        }
        entries.append(e)
        evidence = is_bandcamp_evidence(row, m_info)
        if row["mixxx_deleted"]:
            e["status"] = "skip-hidden"
            continue
        if len(hits) > 1:
            e["status"] = "skip-ambiguous"
            continue
        flac = hits[0]
        f_info = flac_info[flac]
        e["flac_rate"], e["flac_bits"] = f_info["samplerate"], f_info["bits"]
        if len(flac_users[flac]) > 1:
            e["status"] = "skip-flac-matches-several-mp3s"
            continue
        if m_info is None:
            e["status"] = "skip-mp3-unreadable"
            continue
        diff = f_info["duration"] - m_info["duration"]
        e["duration_diff"] = f"{diff:+.3f}"
        if abs(diff) > DURATION_TOLERANCE_S:
            e["status"] = "skip-duration-mismatch"
            continue
        if method in ("folder", "tags") and not evidence and not args.include_unverified:
            e["status"] = "skip-unverified"
            e["note"] = "matched by folder/tags and MP3 shows no Bandcamp origin; --include-unverified to take it"
            continue
        if Path(e["target"]).exists():
            e["status"] = "skip-target-exists"
            continue
        if db.execute("select 1 from track_locations where location = ?", (e["target"],)).fetchone():
            e["status"] = "skip-target-already-in-mixxx"
            continue
        if row["bpm_lock"] and row["beats_version"] and row["samplerate"] != f_info["samplerate"]:
            e["note"] = "locked grid rescaled for new sample rate: spot-check"
        e["status"] = "migrate"
        used.add(flac)

    matched_ids = {e["track_id"] for e in entries}
    for row in rows:
        if row["id"] not in matched_ids and not row["mixxx_deleted"] and is_bandcamp_evidence(row, None):
            entries.append({"status": "unmatched-bandcamp-mp3", "track_id": row["id"], "mp3": row["path"]})
    matched_flacs = {f for _, _, hits in candidates for f in hits}
    for f in flacs:
        if f not in matched_flacs:
            entries.append({"status": "unmatched-flac", "flac_src": str(f)})
    return entries, flac_info


# --- Applying ---

def write_tags(path, row):
    cmd = ["metaflac", "--no-utf8-convert"]
    cmd += [f"--remove-tag={k}" for k in list(TAG_FIELDS) + TAG_ALTERNATES]
    for tag, col in TAG_FIELDS.items():
        val = row[col]
        if col == "bpm":
            val = f"{val:.2f}".rstrip("0").rstrip(".") if val and val > 0 else ""
        if val not in (None, ""):
            cmd.append(f"--set-tag={tag}={val}")
    subprocess.run(cmd + [str(path)], check=True)


def migrate_one(db, e, row, f_info, args, crate_id):
    mp3, flac_src, target = Path(e["mp3"]), Path(e["flac_src"]), Path(e["target"])
    archived = args.archive_dir / mp3.relative_to(args.music_dir)
    partial = target.with_name(target.name + ".partial")
    ratio = f_info["samplerate"] / row["samplerate"] if row["samplerate"] else 1.0

    try:
        shutil.copyfile(flac_src, partial)
        write_tags(partial, row)
        partial.rename(target)
        archived.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(mp3, archived)
        st = target.stat()
        with db:
            db.execute(
                """update track_locations set location=?, filename=?, directory=?, filesize=?,
                       fs_deleted=0, needs_verification=0 where id=?""",
                (str(target), target.name, str(target.parent), st.st_size, row["loc_id"]),
            )
            db.execute(
                """update library set filetype='flac', samplerate=?, channels=?, bitrate=?,
                       duration=?, header_parsed=1, source_synchronized_ms=? where id=?""",
                (f_info["samplerate"], f_info["channels"], f_info["bitrate"], f_info["duration"],
                 st.st_mtime_ns // 1_000_000 + 1, row["id"]),
            )
            if row["beats_version"] and (row["bpm_lock"] or args.keep_grids):
                if ratio != 1.0:
                    db.execute("update library set beats=? where id=?",
                               (rescale_beats(row["beats_version"], row["beats"], ratio), row["id"]))
            else:
                db.execute("update library set beats=NULL, beats_version=NULL, beats_sub_version=NULL where id=?",
                           (row["id"],))
            if ratio != 1.0:
                db.execute(
                    """update cues set position = round(position * ?),
                           length = case when length > 0 then round(length * ?) else length end
                       where track_id = ? and position >= 0""",
                    (ratio, ratio, row["id"]),
                )
            analysis_ids = [r[0] for r in db.execute("select id from track_analysis where track_id=?", (row["id"],))]
            db.execute("delete from track_analysis where track_id=?", (row["id"],))
            db.execute("insert or ignore into crate_tracks (crate_id, track_id) values (?, ?)", (crate_id, row["id"]))
    except Exception:
        # The DB transaction has rolled back; put the files back as they were.
        partial.unlink(missing_ok=True)
        if archived.exists() and not mp3.exists():
            shutil.move(archived, mp3)
        if mp3.exists():
            target.unlink(missing_ok=True)
        raise

    for aid in analysis_ids:
        (args.analysis_dir / str(aid)).unlink(missing_ok=True)
    with open(args.archive_dir / "manifest.tsv", "a", newline="") as fh:
        csv.writer(fh, delimiter="\t").writerow([row["id"], mp3, archived, target, flac_src])


def apply(args, db, entries, flac_info):
    if subprocess.run(["pgrep", "-x", "mixxx"], capture_output=True).returncode == 0:
        sys.exit("Mixxx is running. Close it before --apply.")
    todo = [e for e in entries if e["status"] == "migrate"][: args.limit]
    need = sum(Path(e["flac_src"]).stat().st_size for e in todo)
    free = shutil.disk_usage(args.music_dir).free
    if need * 1.1 > free:
        sys.exit(f"Not enough space: need {need / 1e9:.1f} GB, {free / 1e9:.1f} GB free.")

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = args.db.with_name(f"{args.db.name}.pre-flac-{stamp}")
    with sqlite3.connect(backup) as dst:
        db.backup(dst)
    print(f"Backed up Mixxx DB to {backup}")

    args.archive_dir.mkdir(parents=True, exist_ok=True)
    db.execute("insert or ignore into crates (name) values (?)", (CRATE_NAME,))
    db.commit()
    crate_id = db.execute("select id from crates where name=?", (CRATE_NAME,)).fetchone()[0]

    rows = {r["id"]: r for r in load_mixxx_mp3s(db, args.music_dir)}
    done = failed = 0
    for e in todo:
        try:
            migrate_one(db, e, rows[e["track_id"]], flac_info[Path(e["flac_src"])], args, crate_id)
            e["status"] = "migrated"
            done += 1
        except Exception as ex:
            e["status"], e["note"] = "failed", str(ex)
            failed += 1
            print(f"FAILED {e['mp3']}: {ex}", file=sys.stderr)
    print(f"Migrated {done}, failed {failed}. Crate: '{CRATE_NAME}'.")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--flac-dir", type=Path, default=HOME / "Bandcamp_FLAC")
    p.add_argument("--music-dir", type=Path, default=HOME / "Music")
    p.add_argument("--archive-dir", type=Path, default=HOME / "Bandcamp_MP3s_archive")
    p.add_argument("--db", type=Path, default=HOME / ".mixxx" / "mixxxdb.sqlite")
    p.add_argument("--analysis-dir", type=Path, default=HOME / ".mixxx" / "analysis")
    p.add_argument("--report", type=Path, default=HOME / f"bandcamp-migration-{datetime.date.today()}.tsv")
    p.add_argument("--pairs", type=Path, help='TSV of explicit "mp3<TAB>flac" pairs for names that don\'t match')
    p.add_argument("--apply", action="store_true", help="make changes (default is a dry run)")
    p.add_argument("--limit", type=int, help="migrate at most N tracks (for a trial run)")
    p.add_argument("--keep-grids", action="store_true", help="rescale all beatgrids instead of re-analyzing")
    p.add_argument("--include-unverified", action="store_true",
                   help="also migrate folder/tag matches whose MP3 shows no Bandcamp origin")
    args = p.parse_args()
    for d in ("flac_dir", "music_dir", "archive_dir", "db", "analysis_dir"):
        # No resolve(): paths must compare equal to the ones Mixxx stored.
        setattr(args, d, getattr(args, d).expanduser().absolute())

    for tool in ("ffprobe", "metaflac"):
        if not shutil.which(tool):
            sys.exit(f"{tool} not found")
    if not args.flac_dir.is_dir():
        sys.exit(f"No FLAC folder at {args.flac_dir}; run bandcampsync first.")

    if args.apply:
        db = sqlite3.connect(args.db)
    else:
        db = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
    entries, flac_info = plan(args, db)
    if args.apply:
        apply(args, db, entries, flac_info)
    db.close()

    cols = ["status", "track_id", "method", "mp3", "flac_src", "target", "duration_diff", "mp3_rate",
            "flac_rate", "flac_bits", "bpm_locked", "hotcues", "timesplayed", "note"]
    with open(args.report, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, delimiter="\t", restval="")
        w.writeheader()
        w.writerows(sorted(entries, key=lambda e: (e["status"], e.get("mp3", ""), e.get("flac_src", ""))))

    counts = {}
    for e in entries:
        counts[e["status"]] = counts.get(e["status"], 0) + 1
    print("\n".join(f"{n:6}  {s}" for s, n in sorted(counts.items())))
    rates = {}
    for e in entries:
        if e["status"] in ("migrate", "migrated"):
            rates[(e["flac_rate"], e["flac_bits"])] = rates.get((e["flac_rate"], e["flac_bits"]), 0) + 1
    if rates:
        print("FLAC formats:", ", ".join(f"{r / 1000:g} kHz/{b}-bit: {n}" for (r, b), n in sorted(rates.items())))
    print(f"Report: {args.report.resolve()}" + ("" if args.apply else "  (dry run, nothing changed)"))


if __name__ == "__main__":
    main()

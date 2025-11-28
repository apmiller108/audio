#!/usr/bin/env ruby

# Copyright (c) 2024 Alex P Miller
# Released under the MIT License.

# This script converts WAV files to MP3 format, extracting metadata from filenames
# and prompting the user for additional album metadata. It uses ffmpeg for conversion
# and taglib-ruby for setting ID3 tags.

# It currently expects filenames in the format:
#
#   Artist Name - Album Name - DD Track Name.wav
#
# Where DD is the two-digit track number. The script will prompt for Genre, Year, and Grouping
# for each album (directory). It also looks for a cover.jpg file in the album directory to embed
# as cover art in the MP3 files.
#
# Usage:
#   ruby album-to-mp3.rb [base_directory]
#

require 'fileutils'
require 'shellwords'

# Check for required tools
def check_dependencies
  missing = []
  missing << "ffmpeg" unless system("which ffmpeg > /dev/null 2>&1")
  missing << "gem install taglib-ruby or gem install taglib-ruby --version '< 2'" unless check_gem('taglib')

  unless missing.empty?
    puts "Error: Missing dependencies:"
    missing.each { |dep| puts "  - #{dep}" }
    exit 1
  end
end

def check_gem(gem_name)
  begin
    require gem_name
    true
  rescue LoadError
    false
  end
end

check_dependencies
require 'taglib'

# Color codes
class String
  def green; "\e[32m#{self}\e[0m"; end
  def blue; "\e[34m#{self}\e[0m"; end
  def yellow; "\e[33m#{self}\e[0m"; end
end

# Extract metadata from filename
def extract_metadata(filename)
  basename = File.basename(filename, '.wav')

  # Format: Artist Name - Album Name - DD Track Name.wav
  if basename =~ /^(.*?) - (.*?) - (\d{2}) (.*)$/
    {
      artist: $1.strip,
      album: $2.strip,
      track_num: $3.to_i,
      title: $4.strip
    }
  else
    puts "Warning: Could not parse filename: #{filename}".yellow
    nil
  end
end

# Get album metadata from user
def get_album_metadata(album_dir)
  puts "\nProcessing album in: #{album_dir}".green

  print "Enter Genre: "
  STDOUT.flush
  genre = STDIN.gets.chomp

  print "Enter Year: "
  STDOUT.flush
  year = STDIN.gets.chomp.to_i

  print "Enter Grouping: "
  STDOUT.flush
  grouping = STDIN.gets.chomp

  { genre: genre, year: year, grouping: grouping }
end

# Convert WAV to MP3
def convert_to_mp3(wav_file, mp3_file, metadata, album_metadata, cover_art)
  puts "Converting: #{File.basename(wav_file)}".blue
  puts "  Artist: #{metadata[:artist]} | Album: #{metadata[:album]} | Track: #{metadata[:track_num]} | Title: #{metadata[:title]}"

  # Build ffmpeg command:
  # -n: no overwrite
  # -i: input file
  # -codec:a libmp3lame: use LAME MP3 encoder
  # -b:a 320k: set bitrate to 320 kbps
  # -ar 44100: set audio sample rate to 44.1 kHz
  cmd = [
    'ffmpeg', '-n', '-i', wav_file,
    '-codec:a', 'libmp3lame',
    '-b:a', '320k',
    '-ar', '44100',
    '-loglevel', 'error',
    mp3_file
  ]

  # Run conversion
  success = system(*cmd, [:out, :err] => '/dev/null')

  unless success
    puts "Warning: Conversion failed for #{File.basename(wav_file)}".yellow
    return false
  end

  # Set ID3 tags using TagLib
  TagLib::MPEG::File.open(mp3_file) do |file|
    tag = file.id3v2_tag

    tag.title = metadata[:title]
    tag.artist = metadata[:artist]
    tag.album = metadata[:album]
    tag.genre = album_metadata[:genre]
    tag.year = album_metadata[:year]
    tag.track = metadata[:track_num]

    # Add grouping (TIT1 frame)
    if album_metadata[:grouping] && !album_metadata[:grouping].empty?
      frame = TagLib::ID3v2::TextIdentificationFrame.new("TIT1", TagLib::String::UTF8)
      frame.text = album_metadata[:grouping]
      tag.add_frame(frame)
    end

    # Add cover art
    if cover_art && File.exist?(cover_art)
      apic = TagLib::ID3v2::AttachedPictureFrame.new
      apic.mime_type = "image/jpeg"
      apic.description = "Cover"
      apic.type = TagLib::ID3v2::AttachedPictureFrame::FrontCover
      apic.picture = File.open(cover_art, 'rb') { |f| f.read }
      tag.add_frame(apic)
    end

    file.save
  end

  puts "✓ Completed: #{File.basename(mp3_file)}".green
  true
end

# Main processing
def main(base_dir = '.')
  puts "=== Album to MP3 Converter ===".blue
  puts

  # Find all WAV files
  wav_files = Dir.glob(File.join(base_dir, '**', '*.wav')).sort

  if wav_files.empty?
    puts "No WAV files found in #{base_dir}"
    exit 0
  end

  # Group files by album directory
  albums = wav_files.group_by { |f| File.dirname(f) }

  albums.each do |album_dir, files|
    # Get or load album metadata
    cache_file = File.join(album_dir, '.metadata_cache')

    if File.exist?(cache_file)
      # Load cached metadata
      data = File.read(cache_file).strip.split('|')
      album_metadata = {
        genre: data[0],
        year: data[1].to_i,
        grouping: data[2]
      }
    else
      # Prompt user for metadata
      album_metadata = get_album_metadata(album_dir)

      # Cache it
      File.write(cache_file, "#{album_metadata[:genre]}|#{album_metadata[:year]}|#{album_metadata[:grouping]}")
      puts
    end

    # Find cover art
    cover_art = File.join(album_dir, 'cover.jpg')
    cover_art = nil unless File.exist?(cover_art)

    # Process each file
    files.each do |wav_file|
      mp3_file = wav_file.sub(/\.wav$/i, '.mp3')

      # Skip if already exists
      if File.exist?(mp3_file)
        puts "Skipping (already exists): #{File.basename(mp3_file)}".yellow
        next
      end

      # Extract metadata from filename
      metadata = extract_metadata(wav_file)
      next unless metadata

      # Convert and tag
      convert_to_mp3(wav_file, mp3_file, metadata, album_metadata, cover_art)
    end
  end

  # Clean up cache files
  puts "\nCleaning up temporary files...".blue
  Dir.glob(File.join(base_dir, '**', '.metadata_cache')).each { |f| File.delete(f) }

  puts "\n=== Conversion Complete ===".green
end

# Run the script
main(ARGV[0] || '.')

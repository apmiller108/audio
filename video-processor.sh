#!/bin/bash

# DJ Set Audio Mastering Helper Script
# Usage: ./dj-master.sh process <input.mp4>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function show_help {
    echo "DJ Set Audio Mastering Helper"
    echo ""
    echo "Usage:"
    echo "  $0 process <input.mp4>    - Full automated mastering workflow"
    echo ""
    echo "Workflow:"
    echo "  1. Extracts audio as WAV"
    echo "  2. Opens in Audacity for mastering (apply macro, export wav and close)"
    echo "  3. Converts mastered WAV to MP3 (320kbps)"
    echo "  4. Replaces audio in video"
    echo "  5. Prompts to delete temporary WAV file"
    echo ""
    echo "Output files:"
    echo "  - <name>_mastered.mp4 (for YouTube)"
    echo "  - <name>_mastered.mp3 (for SoundCloud)"
}

function wait_for_audacity {
    local wav_file="$1"
    local pid="$2"

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         WAITING FOR AUDACITY MASTERING${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}In Audacity:${NC}"
    echo "  1. Tools → Apply Macro → DJ-Master"
    echo "  2. File → Export → Export Audio"
    echo "  3. Save as WAV (OVERWRITE THE ORIGINAL FILE)"
    echo "  4. Close Audacity"
    echo ""
    echo -e "${YELLOW}Waiting for Audacity to close...${NC}"
    echo ""

    # Wait for Audacity process to finish
    wait $pid 2>/dev/null || true

    echo -e "${GREEN}Audacity closed. Continuing...${NC}"
    echo ""
}

function process_full_workflow {
    local input_file="$1"

    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: Input file '$input_file' not found${NC}"
        exit 1
    fi

    local base_name="${input_file%.*}"
    local extracted_wav="${base_name}_extracted.wav"
    local mastered_mp3="${base_name}_mastered.mp3"
    local mastered_video="${base_name}_mastered.mp4"

    # Step 1: Extract audio as WAV
    echo -e "${GREEN}[1/5] Extracting audio as WAV...${NC}"
    ffmpeg -i "$input_file" -vn "$extracted_wav" -y

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error extracting audio${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Audio extracted: $extracted_wav${NC}"

    # Step 2: Open in Audacity and wait
    echo ""
    echo -e "${GREEN}[2/5] Opening in Audacity for mastering...${NC}"
    audacity "$extracted_wav" &
    local audacity_pid=$!

    wait_for_audacity "$extracted_wav" $audacity_pid

    # Step 3: Convert WAV to MP3
    echo -e "${GREEN}[3/5] Converting mastered WAV to MP3 (320kbps)...${NC}"

    if [ ! -f "$extracted_wav" ]; then
        echo -e "${RED}Error: Mastered WAV file not found. Did you export from Audacity?${NC}"
        exit 1
    fi

    ffmpeg -i "$extracted_wav" -acodec libmp3lame -b:a 320k -ar 44100 "$mastered_mp3" -y

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error converting to MP3${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ MP3 created: $mastered_mp3${NC}"

    # Step 4: Replace audio in video
    echo ""
    echo -e "${GREEN}[4/5] Creating mastered video...${NC}"
    echo "  Video: $input_file"
    echo "  Audio: $mastered_mp3"
    echo "  Output: $mastered_video"
    echo ""

    ffmpeg -i "$input_file" -i "$mastered_mp3" \
        -map 0:v:0 -map 1:a:0 \
        -c:v copy -c:a libmp3lame -b:a 320k -ar 44100 \
        "$mastered_video" -y

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error creating mastered video${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Mastered video created: $mastered_video${NC}"

    # Step 5: Cleanup prompt
    echo ""
    echo -e "${GREEN}[5/5] Cleanup${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           MASTERING COMPLETE!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Output files:${NC}"
    echo "  📹 YouTube: $mastered_video"
    echo "  🎵 SoundCloud: $mastered_mp3"
    echo ""

    # Show file sizes
    local original_size=$(du -h "$input_file" | cut -f1)
    local video_size=$(du -h "$mastered_video" | cut -f1)
    local mp3_size=$(du -h "$mastered_mp3" | cut -f1)
    local wav_size=$(du -h "$extracted_wav" | cut -f1)

    echo "File sizes:"
    echo "  Original video: $original_size"
    echo "  Mastered video: $video_size"
    echo "  Mastered MP3:   $mp3_size"
    echo "  Temp WAV:       $wav_size"
    echo ""

    # Prompt to delete WAV
    echo -e "${YELLOW}Delete temporary WAV file ($wav_size)?${NC}"
    read -p "Delete $extracted_wav? [y/N]: " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$extracted_wav"
        echo -e "${GREEN}✓ Deleted: $extracted_wav${NC}"
    else
        echo -e "${YELLOW}Kept: $extracted_wav${NC}"
    fi

    # Prompt to original mp4
    echo -e "${YELLOW}Delete original file ($original_size)?${NC}"
    read -p "Delete $input_file? [y/N]: " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$input_file"
        echo -e "${GREEN}✓ Deleted: $input_file${NC}"
    else
        echo -e "${YELLOW}Kept: $input_file${NC}"
    fi

    echo ""
    echo -e "${GREEN}All done! Ready to upload.${NC}"
}

# Main script logic
case "$1" in
    process)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Please provide input file${NC}"
            show_help
            exit 1
        fi
        process_full_workflow "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Error: Invalid command${NC}"
        show_help
        exit 1
        ;;
esac

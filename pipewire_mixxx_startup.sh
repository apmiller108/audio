#!/usr/bin/env bash

# This is a pipewire based setup script to run Mixxx DJ software using 4 decks
# "piped" Bitwig audio channels. From there the audio is sent out an external
# mixer. MIDI control and MIDI clock are included as well. Recording is
# supported by routing the master or record channels from external mixer to
# whatever recording software via audio interface.

# In the event the volume is very low on a soundcard, use alsamixer or
# pavucontrol (Pulse Audio Volume Control) to set sound card volume levels.

# Default configuration
DAW=""
SHOW_INFO=false
FORCE=false
RECORD=false

# Configuration paths
BITWIG_PROJECT="/home/apmiller/Bitwig Studio/Projects/pmixxx/pmixxx.bwproject"

# Device configuration - add your devices here
# Maps device friendly names to search patterns used in pw-link to find device IDs.
declare -A MIDI_DEVICES=(
    ["Midi Fighter"]="Midi Fighter"
    ["K2 MIDI"]="K2 MIDI"
    ["UMC204HD"]="UMC204HD 192k MIDI"
    ["Midi Through"]="Midi Through"
    ["Arduino Leonardo"]="Arduino Leonardo MIDI"
    ["SQ-1"]="SQ-1.+CTRL"
    ["Audio 8 DJ"]="Midi.+Audio\s8\sDJ"
    ["Raster"]="Raster MIDI"
)

# Parse command line arguments
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --bitwig        Use Bitwig as the DAW
    --info          Show MIDI device information and exit
    -r, --record    Enable recording mode (starts projectMSDL and OBS)
    -f, --force     Force start even if checks fail
    -h, --help      Show this help message

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --bitwig)
            DAW="bitwig"
            shift
            ;;
        --info)
            SHOW_INFO=true
            shift
            ;;
        -r|--record)
            RECORD=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Utility functions
find_pw_output_id() {
    local search_string="$1"
    pw-link -I -o | grep -E "$search_string" | sed 's/^[[:space:]]*//' | \
        sed 's/\([[:digit:]]*\).*$/\1/'
}

find_pw_input_id() {
    local search_string="$1"
    pw-link -I -i | grep -E "$search_string" | sed 's/^[[:space:]]*//' | \
        sed 's/\([[:digit:]]*\).*$/\1/'
}

show_midi_info() {
    echo "=== MIDI OUTPUT DEVICES ==="
    printf "%-20s %-10s %s\n" "DEVICE NAME" "ID" "FULL NAME"
    echo "----------------------------------------"

    for device_key in "${!MIDI_DEVICES[@]}"; do
        device_pattern="${MIDI_DEVICES[$device_key]}"
        device_id=$(find_pw_output_id "$device_pattern")
        full_name=$(pw-link -I -o | grep -E "$device_pattern" | sed 's/^[[:space:]]*//' | head -1)
        printf "%-20s %-10s %s\n" "$device_key" "${device_id:-N/A}" "${full_name:-Not found}"
    done

    echo ""
    echo "=== MIDI INPUT DEVICES ==="
    printf "%-20s %-10s %s\n" "DEVICE NAME" "ID" "FULL NAME"
    echo "----------------------------------------"

    for device_key in "${!MIDI_DEVICES[@]}"; do
        device_pattern="${MIDI_DEVICES[$device_key]}"
        device_id=$(find_pw_input_id "$device_pattern")
        full_name=$(pw-link -I -i | grep -E "$device_pattern" | sed 's/^[[:space:]]*//' | head -1)
        printf "%-20s %-10s %s\n" "$device_key" "${device_id:-N/A}" "${full_name:-Not found}"
    done

    echo ""
    echo "=== VIRTUAL MIDI DEVICES ==="
    for i in {0..3}; do
        virt_id=$(find_pw_input_id "VirMIDI\s+.+-$i")
        virt_name=$(pw-link -I -i | grep -E "VirMIDI\s+.+-$i" | sed 's/^[[:space:]]*//' | head -1)
        printf "%-20s %-10s %s\n" "VirMIDI-$i" "${virt_id:-N/A}" "${virt_name:-Not found}"
    done
}

setup_virtual_midi() {
  echo "Setting up virtual MIDI ports..."

  if lsmod | grep -q "snd_virmidi"; then
    echo "snd-virmidi module already loaded"
  else
    echo "Loading snd-virmidi module (requires sudo)..."
    sudo modprobe snd-virmidi
  fi
}


get_device_ids() {
    # Get all device IDs
    midi_fighter_out=$(find_pw_output_id "${MIDI_DEVICES["Midi Fighter"]}")
    midi_fighter_in=$(find_pw_input_id "${MIDI_DEVICES["Midi Fighter"]}")
    xonek2_midi_out=$(find_pw_output_id "${MIDI_DEVICES["K2 MIDI"]}")
    umc204_midi_in=$(find_pw_input_id "${MIDI_DEVICES["UMC204HD"]}")
    umc204_midi_out=$(find_pw_output_id "${MIDI_DEVICES["UMC204HD"]}")
    midi_thru_in=$(find_pw_input_id "${MIDI_DEVICES["Midi Through"]}")
    midi_thru_out=$(find_pw_output_id "${MIDI_DEVICES["Midi Through"]}")
    mixxx_midi_clock_out=$(find_pw_output_id "${MIDI_DEVICES["Arduino Leonardo"]}")
    sq1_midi_in=$(find_pw_input_id "${MIDI_DEVICES["SQ-1"]}")
    dj_8_midi_out=$(find_pw_output_id "${MIDI_DEVICES["Audio 8 DJ"]}")
    dj_8_midi_in=$(find_pw_input_id "${MIDI_DEVICES["Audio 8 DJ"]}")
    raster_midi_in=$(find_pw_input_id "${MIDI_DEVICES["Raster"]}")

    # Virtual MIDI devices
    virtual_midi_in0=$(find_pw_input_id "VirMIDI\s+.+-0")
    virtual_midi_in1=$(find_pw_input_id "VirMIDI\s+.+-1")
    virtual_midi_in2=$(find_pw_input_id "VirMIDI\s+.+-2")
    virtual_midi_in3=$(find_pw_input_id "VirMIDI\s+.+-3")
}

start_bitwig() {
    echo "Starting Bitwig Studio..."
    bitwig-studio "$BITWIG_PROJECT" &
    echo "Waiting for Bitwig to load..."
    sleep 15
}

start_mixxx() {
    echo "Starting Mixxx..."
    mixxx &
    echo "Waiting for Mixxx to load..."
    sleep 10
}

start_recording_tools() {
    echo "Starting recording tools..."

    # Start projectMSDL
    echo "Starting projectMSDL..."
    projectMSDL &

    # Start OBS
    echo "Starting OBS..."
    flatpak run com.obsproject.Studio &

    echo "Waiting for recording tools to load..."
    sleep 5
}

create_link_with_error_handling() {
  local source="$1"
  local target="$2"

  echo "Attempting to link: $source -> $target"
  if ! pw-link "$source" "$target" 2>/dev/null; then
    echo "ERROR: Failed to link '$source' to '$target' - one or both ports may not exist"
    return 1
  else
    echo "Successfully linked: $source -> $target"
  fi
}

setup_bitwig_audio_routing() {
    echo "Setting up Bitwig audio routing..."
    create_link_with_error_handling "Mixxx:out_0" "Bitwig Studio:Mixxx D1_L"
    create_link_with_error_handling "Mixxx:out_1" "Bitwig Studio:Mixxx D1_R"
    create_link_with_error_handling "Mixxx:out_2" "Bitwig Studio:Mixxx D2_L"
    create_link_with_error_handling "Mixxx:out_3" "Bitwig Studio:Mixxx D2_R"
    create_link_with_error_handling "Mixxx:out_4" "Bitwig Studio:Mixxx D3_L"
    create_link_with_error_handling "Mixxx:out_5" "Bitwig Studio:Mixxx D3_R"
    create_link_with_error_handling "Mixxx:out_6" "Bitwig Studio:Mixxx D4_L"
    create_link_with_error_handling "Mixxx:out_7" "Bitwig Studio:Mixxx D4_R"
}

setup_projectmsdl_audio_routing() {
  echo "Setting up projectMSDL audio routing..."

  # Connect UMC204HD audio inputs to projectMSDL
  create_link_with_error_handling \
    "alsa_input.usb-BEHRINGER_UMC204HD_192k-00.Direct__hw_U192k__source:capture_FL" \
    "projectMSDL:input_FL"

  create_link_with_error_handling \
    "alsa_input.usb-BEHRINGER_UMC204HD_192k-00.Direct__hw_U192k__source:capture_FR" \
    "projectMSDL:input_FR"
}

setup_midi_routing() {
    echo "Setting up MIDI routing..."

    # Virtual MIDI routing for DAW
    [[ -n "$virtual_midi_in0" && -n "$mixxx_midi_clock_out" ]] && \
        create_link_with_error_handling "$mixxx_midi_clock_out" "$virtual_midi_in0"
    [[ -n "$virtual_midi_in1" && -n "$xonek2_midi_out" ]] && \
        create_link_with_error_handling "$xonek2_midi_out" "$virtual_midi_in1"
    [[ -n "$virtual_midi_in2" && -n "$midi_fighter_out" ]] && \
        create_link_with_error_handling "$midi_fighter_out" "$virtual_midi_in2"

    # Midi Fighter routing
    [[ -n "$midi_fighter_out" && -n "$midi_thru_in" ]] && \
        create_link_with_error_handling "$midi_fighter_out" "$midi_thru_in"
    [[ -n "$midi_fighter_out" && -n "$dj_8_midi_in" ]] && \
        create_link_with_error_handling "$midi_fighter_out" "$dj_8_midi_in"

    # MIDI Clock routing
    if [[ -n "$mixxx_midi_clock_out" ]]; then
        [[ -n "$dj_8_midi_in" ]] && create_link_with_error_handling "$mixxx_midi_clock_out" "$dj_8_midi_in"
        [[ -n "$sq1_midi_in" ]] && create_link_with_error_handling "$mixxx_midi_clock_out" "$sq1_midi_in"
        [[ -n "$raster_midi_in" ]] && create_link_with_error_handling "$mixxx_midi_clock_out" "$raster_midi_in"
    fi
}

# Main execution
main() {
    if pgrep -x "chrome" > /dev/null && [[ "$FORCE" == false ]]; then
        echo "⚠️ Close chrome first. Use --force to override."
        exit 1
    fi

    system76-power profile performance

    if [[ "$SHOW_INFO" == true ]]; then
        setup_virtual_midi
        show_midi_info
        exit 0
    fi

    # Validate DAW selection
    if [[ -z "$DAW" ]]; then
        echo "Starting DJ setup without DAW"
    fi

    # Setup virtual MIDI
    setup_virtual_midi

    # Start DAW
    case "$DAW" in
        "bitwig")
            echo "Starting DJ setup with $DAW..."
            start_bitwig
            ;;
    esac

    # Start Mixxx
    start_mixxx

    # Start recording tools if --record flag is set
    if [[ "$RECORD" == true ]]; then
        start_recording_tools
    fi

    if [[ -z "$DAW" ]]; then
        # Assume setting up Mixxx outputs directly to Audio DJ 8. For some
        # reason the D output does not show up in Mixxx UI, so we link manually
        # here.
        pw-link -d "Mixxx:out_4" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.Direct__hw_U192k__sink:playback_FL"
        pw-link -d "Mixxx:out_5" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.Direct__hw_U192k__sink:playback_FR"
        pw-link "Mixxx:out_4" "alsa_output.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-d-output:playback_FL"
        pw-link "Mixxx:out_5" "alsa_output.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-d-output:playback_FR"
    fi

    # Get device IDs
    get_device_ids

    # Setup audio routing
    case "$DAW" in
        "bitwig")
            setup_bitwig_audio_routing
            ;;
    esac

    # Setup projectMSDL audio routing if recording
    if [[ "$RECORD" == true ]]; then
      setup_projectmsdl_audio_routing
    fi

    # Setup MIDI routing
    setup_midi_routing

    echo "DJ setup complete!"
    if [[ "$RECORD" == true ]]; then
        echo "Recording mode enabled - projectMSDL and OBS are running"
    fi
}

# Run main function
main "$@"

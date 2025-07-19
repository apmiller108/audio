#!/usr/bin/env bash

# This is a pipewire based setup script to run Mixxx DJ sofware using 4 decks
# "piped" through Ardour audio channels, then out to an external mixer. Midi
# control and MIDI clock are included as well. Recording is supported by routing
# audio from external mixer to Ardour via soundcard.

# In the event the volume is very low on a soundcard, use alsamixer or
# pavucontrol (Pulse Audio Volume Control) to set sound card volume levels.

while getopts r: flag
do
  case "${flag}" in
    r) record=${OPTARG};;
  esac
done

find_pw_output_id() {
  local search_string="$1"
  pw-link -I -o | grep "$search_string" | sed 's/^[[:space:]]*//' | \
    sed 's/\([[:digit:]]*\).*$/\1/'
}

find_pw_input_id() {
  local search_string="$1"
  pw-link -I -i | grep "$search_string" | sed 's/^[[:space:]]*//' | \
    sed 's/\([[:digit:]]*\).*$/\1/'
}
# Device inputs and outputs variables. Find I/O ID from partial device name.
midi_fighter_out=$(find_pw_output_id "Midi Fighter")
midi_fighter_in=$(find_pw_input_id "Midi Fighter")
xonek2_midi_out=$(find_pw_output_id "K2 MIDI")
xonepx5_midi_out=$(find_pw_output_id "PX5 MIDI")
xonepx5_midi_in=$(find_pw_input_id "PX5 MIDI")
umc204_midi_in=$(find_pw_input_id "UMC204HD 192k MIDI")
umc204_midi_out=$(find_pw_output_id "UMC204HD 192k MIDI")
midi_thru_in=$(find_pw_input_id "Midi Through")
midi_thru_out=$(find_pw_output_id "Midi Through")
mixxx_midi_clock_out=$(find_pw_output_id "Arduino Leonardo MIDI")
sq1_midi_in=$(find_pw_output_id "SQ-1 SQ-1 _ CTRL")

# Start Ardour Mixxx project
# PIPEWIRE_QUANTUM=256/48000 Ardour7 /home/apmiller/mixxx_4_decks_v2 &
# Ardour7 /home/apmiller/mixxx_4_decks_v2 &
# wait for Ardour to finish loading
# sleep 15
# Start Mixxx with `--developer` flag to allow mapping to MIDI Through port and
# verbose logging
# PIPEWIRE_QUANTUM=256/48000 mixxx &
mixxx &
# Wait for Mixxx to finish loading
sleep 10

# Ardour inputs and outputs variables. Find I/O ID from partial device name.
ardour_midi_clock_in=$(find_pw_input_id "MIDI Clock in")
ardour_midi_control_in=$(find_pw_input_id "MIDI Control in")

# Clean up useless links
pw-link -d Mixxx:out_0 "ardour:physical_audio_input_monitor_enable"
pw-link -d Mixxx:out_1 "ardour:LTC in"
pw-link -d Mixxx:out_2 "ardour:Master/audio_in 1"
pw-link -d Mixxx:out_3 "ardour:Master/audio_in 2"
pw-link -d Mixxx:out_4 "ardour:Deck3/audio_in 1"
pw-link -d Mixxx:out_5 "ardour:Deck3/audio_in 2"
pw-link -d Mixxx:out_6 "ardour:Deck1/audio_in 1"
pw-link -d Mixxx:out_7 "ardour:Deck1/audio_in 2"
pw-link -d Mixxx:out_6 "ardour:->D3+B3/audio_return 1"
pw-link -d Mixxx:out_7 "ardour:->D3+B3/audio_return 2"

# Setup Mixxx output mapping
pw-link Mixxx:out_0 "ardour:Deck1/audio_in 1"
pw-link Mixxx:out_1 "ardour:Deck1/audio_in 2"
pw-link Mixxx:out_2 "ardour:Deck2/audio_in 1"
pw-link Mixxx:out_3 "ardour:Deck2/audio_in 2"
pw-link Mixxx:out_4 "ardour:Deck3/audio_in 1"
pw-link Mixxx:out_5 "ardour:Deck3/audio_in 2"
pw-link Mixxx:out_6 "ardour:Deck4/audio_in 1"
pw-link Mixxx:out_7 "ardour:Deck4/audio_in 2"

# Setup MIDI connections

# Midi Fighter to control effects in Ardour
pw-link $midi_fighter_out $midi_thru_in

# Midi Fighter to control Beebo
pw-link $midi_fighter_out $umc204_midi_in
pw-link $umc204_midi_in $umc204_midi_out

# Mixxx MIDI Clock output
pw-link $mixxx_midi_clock_out $ardour_midi_clock_in
pw-link $mixxx_midi_clock_out $xonepx5_midi_in
pw-link $mixxx_midi_clock_out $umc204_midi_in # To Beebo via UMC in->out above
pw-link $mixxx_midi_clock_out $sq1_midi_in

# For Xonek2 via x-link, which controls some effects in Ardour (eg, filter, external send)
pw-link $xonepx5_midi_out $midi_thru_in
pw-link $midi_thru_out $ardour_midi_control_in

if [ -n "$record" ]; then
  Ardour7 /home/apmiller/Recording &
fi

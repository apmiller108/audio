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

# Device inputs and outputs variables. Find I/O ID from partial device name.
midi_fighter_out=$(pw-link -I -o | grep "Midi Fighter" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
midi_fighter_in=$(pw-link -I -i | grep "Midi Fighter" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
xonek2_midi_out=$(pw-link -I -o | grep "K2 MIDI" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
xonepx5_midi_out=$(pw-link -I -o | grep "PX5 MIDI" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
umc204_midi_in=$(pw-link -I -i | grep "UMC204HD 192k MIDI" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
umc204_midi_out=$(pw-link -I -o | grep "UMC204HD 192k MIDI" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
midi_thru_in=$(pw-link -I -i | grep "Midi Through" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
midi_thru_out=$(pw-link -I -o | grep "Midi Through" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')

# Start Ardour Mixxx project
Ardour7 /home/apmiller/mixxx_4_decks_v2 &
# wait for Ardour to finish loading
sleep 10
# Start Mixxx with `--developer` flag to allow mapping to MIDI Through port
mixxx -platform xcb &
# Wait for Mixxx to finish loading
sleep 15

killall speech-dispatcher # Not sure why this is even running.

# Ardour inputs and outputs variables. Find I/O ID from partial device name.
midi_clock_in=$(pw-link -I -i | grep "MIDI Clock in" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
midi_control_in=$(pw-link -I -i | grep "MIDI Control In" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')

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

pw-link $xonek2_midi_out $midi_thru_in
pw-link $xonek2_midi_out $umc204_midi_in

pw-link $midi_fighter_out $midi_thru_in
pw-link $midi_fighter_out $umc204_midi_in

pw-link $xonepx5_midi_out $umc204_midi_in
pw-link $xonepx5_midi_out $midi_clock_in

pw-link $midi_thru_out $midi_control_in

if [ -n "$record" ]; then
  Ardour7 /home/apmiller/Recording &
fi

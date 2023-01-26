#!/usr/bin/env bash

# Start Ardour Mixxx project
Ardour6 /home/apmiller/mixxx_4_decks &
# Start Mixxx with `--developer` flag to allow mapping to MIDI Through port
mixxx -platform xcb --developer &

# Wait for Ardour and Mixxx to finish loading
sleep 20

# TODO: update this to use pw-link -d. use qgraph to see which links need cleaning up
# Clean up busted connections
pw-link -d "Midi-Bridge:BEHRINGER UMC204HD 192k at usb-0000:00:14-0-2-4- high speed:(capture_0) UMC204HD 192k MIDI 1" \
        "ardour:physical_midi_input_monitor_enable"
pw-link -d "Midi-Bridge:XONE:K2 3:(capture_0) XONE:K2 MIDI 1" "ardour:physical_midi_input_monitor_enable"
pw-link -d "Midi-Bridge:XONE:K2 3:(capture_0) XONE:K2 MIDI 1" "ardour:MIDI Control In"
pw-link -d alsa_input.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_mono_in_U192k_0_0__source:capture_MONO "ardour:physical_audio_input_monitor_enable"
pw-link -d alsa_input.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_mono_in_U192k_0_1__source:capture_MONO "ardour:physical_audio_input_monitor_enable"
pw-link -d alsa_input.pci-0000_00_1f.3.stereo-fallback:capture_FL "ardour:physical_audio_input_monitor_enable"
pw-link -d alsa_input.pci-0000_00_1f.3.stereo-fallback:capture_FR "ardour:physical_audio_input_monitor_enable"
pw-link -d Mixxx:out_0 "ardour:physical_audio_input_monitor_enable"
pw-link -d Mixxx:out_1 "ardour:LTC in"
pw-link -d Mixxx:out_2 "ardour:Master/audio_in 1"
pw-link -d Mixxx:out_3 "ardour:Master/audio_in 2"
pw-link -d Mixxx:out_4 "ardour:Deck 3/audio_in 1"
pw-link -d Mixxx:out_5 "ardour:Deck 3/audio_in 2"
pw-link -d Mixxx:out_6 "ardour:->D3+B3/audio_return 1"
pw-link -d Mixxx:out_7 "ardour:->D3+B3/audio_return 2"
jack_disconnect "ardour:auditioner/audio_out 1" system:playback_1
jack_disconnect "ardour:auditioner/audio_out 2" system:playback_2

# TODO update this to use pw-link. The IO names should be the same
# Setup Mixxx output mapping
jack_connect Mixxx:out_0 "ardour:Deck 1/audio_in 1"
jack_connect Mixxx:out_1 "ardour:Deck 1/audio_in 2"
jack_connect Mixxx:out_2 "ardour:Deck 2/audio_in 1"
jack_connect Mixxx:out_3 "ardour:Deck 2/audio_in 2"
jack_connect Mixxx:out_4 "ardour:Deck 3/audio_in 1"
jack_connect Mixxx:out_5 "ardour:Deck 3/audio_in 2"
jack_connect Mixxx:out_6 "ardour:Deck 4/audio_in 1"
jack_connect Mixxx:out_7 "ardour:Deck 4/audio_in 2"

# TODO update this to use pw-link. Use pw-link -o to get the output name
# Setup recording from external mixer into Ardour
jack_connect system:capture_1 "ardour:Master Mix/audio_in 1"
jack_connect system:capture_2 "ardour:Master Mix/audio_in 2"

# TODO update this to use pw-link. Use pw-link -i to get the hardware input names
# Setup Ardour outputs to sound cards
jack_connect "ardour:D1+B1/audio_out 1" XONEK2:playback_3
jack_connect "ardour:D1+B1/audio_out 2" XONEK2:playback_4
jack_connect "ardour:D2+B2/audio_out 1" XONEK2:playback_1
jack_connect "ardour:D2+B2/audio_out 2" XONEK2:playback_2
jack_connect "ardour:D3+B3/audio_out 1" system:playback_3
jack_connect "ardour:D3+B3/audio_out 2" system:playback_4
jack_connect "ardour:D4+B4/audio_out 1" system:playback_1
jack_connect "ardour:D4+B4/audio_out 2" system:playback_2

# TODO update this to use pw-link
# Setup MIDI connections
jack_connect "a2j:XONE:K2 [28] (capture): XONE:K2 MIDI 1" "ardour:MIDI Control In"
jack_connect "a2j:XONE:K2 [28] (capture): XONE:K2 MIDI 1" "a2j:UMC204HD 192k [24] (playback): UMC204HD 192k MIDI 1"
jack_connect "a2j:UMC204HD 192k [24] (capture): UMC204HD 192k MIDI 1" "ardour:MIDI Clock in"
jack_connect "a2j:UMC204HD 192k [24] (capture): UMC204HD 192k MIDI 1" "a2j:UMC204HD 192k [24] (playback): UMC204HD 192k MIDI 1"

jack_connect "a2j:XONE:K2 [28] (capture): XONE:K2 MIDI 1" "a2j:UMC204HD 192k [20] (playback): UMC204HD 192k MIDI 1"
jack_connect "a2j:UMC204HD 192k [20] (capture): UMC204HD 192k MIDI 1" "ardour:MIDI Clock in"
jack_connect "a2j:UMC204HD 192k [20] (capture): UMC204HD 192k MIDI 1" "a2j:UMC204HD 192k [20] (playback): UMC204HD 192k MIDI 1"

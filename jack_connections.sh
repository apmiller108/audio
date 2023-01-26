#!/usr/bin/env bash

# Clean up busted connections
jack_disconnect "ardour:auditioner/audio_out 1" system:playback_1
jack_disconnect "ardour:auditioner/audio_out 2" system:playback_2
jack_disconnect system:capture_1 "ardour:physical_audio_input_monitor_enable"
jack_disconnect system:capture_2 "ardour:physical_audio_input_monitor_enable"
jack_disconnect Mixxx:out_0 ardour:physical_audio_input_monitor_enable
jack_disconnect Mixxx:out_1 "ardour:LTC in"
jack_disconnect Mixxx:out_2 "ardour:Master/audio_in 1"
jack_disconnect Mixxx:out_3 "ardour:Master/audio_in 2"
jack_disconnect Mixxx:out_4 "ardour:Deck 3/audio_in 1"
jack_disconnect Mixxx:out_5 "ardour:Deck 3/audio_in 2"
jack_disconnect Mixxx:out_6 "ardour:Deck 1/audio_in 1"
jack_disconnect Mixxx:out_7 "ardour:Deck 1/audio_in 2"
jack_disconnect Mixxx:out_6 "ardour:Deck 1/audio_in 1"
jack_disconnect Mixxx:out_7 "ardour:Deck 1/audio_in 2"
jack_disconnect Mixxx:out_6 "ardour:->D3+B3/audio_return 1"
jack_disconnect Mixxx:out_7 "ardour:->D3+B3/audio_return 2"

# Setup Mixxx output mapping
jack_connect Mixxx:out_0 "ardour:Deck 1/audio_in 1"
jack_connect Mixxx:out_1 "ardour:Deck 1/audio_in 2"
jack_connect Mixxx:out_2 "ardour:Deck 2/audio_in 1"
jack_connect Mixxx:out_3 "ardour:Deck 2/audio_in 2"
jack_connect Mixxx:out_4 "ardour:Deck 3/audio_in 1"
jack_connect Mixxx:out_5 "ardour:Deck 3/audio_in 2"
jack_connect Mixxx:out_6 "ardour:Deck 4/audio_in 1"
jack_connect Mixxx:out_7 "ardour:Deck 4/audio_in 2"

# Setup recording from external mixer into Ardour
jack_connect system:capture_1 "ardour:Master Mix/audio_in 1"
jack_connect system:capture_2 "ardour:Master Mix/audio_in 2"

# Setup Ardour outputs to sound cards
jack_connect "ardour:D1+B1/audio_out 1" XONEK2:playback_3
jack_connect "ardour:D1+B1/audio_out 2" XONEK2:playback_4
jack_connect "ardour:D2+B2/audio_out 1" XONEK2:playback_1
jack_connect "ardour:D2+B2/audio_out 2" XONEK2:playback_2
jack_connect "ardour:D3+B3/audio_out 1" system:playback_3
jack_connect "ardour:D3+B3/audio_out 2" system:playback_4
jack_connect "ardour:D4+B4/audio_out 1" system:playback_1
jack_connect "ardour:D4+B4/audio_out 2" system:playback_2

# Setup MIDI connections
jack_connect "a2j:XONE:K2 [28] (capture): XONE:K2 MIDI 1" "ardour:MIDI Control In"
jack_connect "a2j:XONE:K2 [28] (capture): XONE:K2 MIDI 1" "a2j:UMC204HD 192k [24] (playback): UMC204HD 192k MIDI 1"
jack_connect "a2j:UMC204HD 192k [24] (capture): UMC204HD 192k MIDI 1" "ardour:MIDI Clock in"
jack_connect "a2j:UMC204HD 192k [24] (capture): UMC204HD 192k MIDI 1" "a2j:UMC204HD 192k [24] (playback): UMC204HD 192k MIDI 1"


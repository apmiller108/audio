#!/usr/bin/env bash

# This is a pipewire based setup script to run Mixxx DJ sofware using 4 decks
# "piped" through Ardour audio channels, then out to an external mixer. Midi
# control and MIDI clock are included as well. Recording is supported by routing
# audio from external mixer to Ardour via soundcard.

# In the event the volume is very low on a soundcard, use alsamixer or
# pavucontrol (Pulse Audio Volume Control) to set sound card volume levels.

# Device inputs and outputs variables. Find I/O ID from partial device name.
midi_fighter_out=$(pw-link -I -o | grep "Midi Fighter" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
midi_fighter_in=$(pw-link -I -i | grep "Midi Fighter" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
xonek2_midi_out=$(pw-link -I -o | grep "K2 MIDI" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
umc204_midi_in=$(pw-link -I -i | grep "UMC204HD 192k MIDI" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
umc204_midi_out=$(pw-link -I -o | grep "UMC204HD 192k MIDI" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
audio8_midi_out=$(pw-link -I -o | grep "Audio 8 DJ" | sed 's/^[[:space:]]*//' | sed 's/\([[:digit:]]*\).*$/\1/')
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

# Clean up busted connections. I don't know why these exist by default, but they
# are useless and need to be disconnected.
# pw-link -d alsa_input.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_mono_in_U192k_0_0__source:capture_MONO "ardour:physical_audio_input_monitor_enable"
# pw-link -d alsa_input.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_mono_in_U192k_0_1__source:capture_MONO "ardour:physical_audio_input_monitor_enable"
# pw-link -d alsa_input.pci-0000_00_1f.3.stereo-fallback:capture_FL "ardour:physical_audio_input_monitor_enable"
# pw-link -d alsa_input.pci-0000_00_1f.3.stereo-fallback:capture_FR "ardour:physical_audio_input_monitor_enable"
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
# pw-link -d "ardour:auditioner/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_0_1__sink:playback_FL"
# pw-link -d "ardour:auditioner/audio_out 2" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_0_1__sink:playback_FR"
# pw-link -d "ardour:auditioner/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.pro-output-0:playback_AUX0"
# pw-link -d "ardour:auditioner/audio_out 2" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.pro-output-0:playback_AUX1"
# pw-link -d "ardour:Click/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.pro-output-0:playback_AUX0"
# pw-link -d "ardour:Click/audio_out 2" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.pro-output-0:playback_AUX1"
# pw-link -d "ardour:Click/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_0_1__sink:playback_FL"
# pw-link -d "ardour:Click/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_0_1__sink:playback_FR"
# pw-link -d "ardour:Deck4/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_2_3__sink:playback_FL"
# pw-link -d "ardour:Deck4/audio_out 2" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_2_3__sink:playback_FR"
# pw-link -d "ardour:Deck3/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_0_1__sink:playback_FL"
# pw-link -d "ardour:Deck3/audio_out 2" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_0_1__sink:playback_FR"
# pw-link -d "alsa_input.usb-DisplayLink_Subosen_4K_Graphic_Docking_SUBN293105480-02.analog-stereo:capture_FL" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-DisplayLink_Subosen_4K_Graphic_Docking_SUBN293105480-02.analog-stereo:capture_FR" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.pci-0000_00_1f.3.stereo-fallback.6:capture_FL" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.pci-0000_00_1f.3.stereo-fallback.6:capture_FR" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.pci-0000_00_1f.3.stereo-fallback.6:capture_FL" "ardour:LTC in"
# pw-link -d "alsa_input.pci-0000_00_1f.3.stereo-fallback.6:capture_FR" "ardour:LTC in"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.pro-input-0:capture_AUX0" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.pro-input-0:capture_AUX1" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.pci-0000_00_1f.3.pro-input-0:capture_AUX0" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.pci-0000_00_1f.3.pro-input-1:capture_AUX1" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-BEHRINGER_UMC204HD_192k-00.pro-input-0:capture_AUX0" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-BEHRINGER_UMC204HD_192k-00.pro-input-0:capture_AUX1" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_output.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-a:monitor_FL" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_output.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-a:monitor_FR" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_output.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-b:monitor_FL" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_output.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-b:monitor_FR" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-a:capture_FL" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-a:capture_FR" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-b:capture_FL" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-b:capture_FR" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-c-input:capture_FL" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-c-input:capture_FR" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-d-input:capture_FL" "ardour:physical_audio_input_monitor_enable"
# pw-link -d "alsa_input.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00.analog-stereo-d-input:capture_FR" "ardour:physical_audio_input_monitor_enable"


# Setup Mixxx output mapping
pw-link Mixxx:out_0 "ardour:Deck1/audio_in 1"
pw-link Mixxx:out_1 "ardour:Deck1/audio_in 2"
pw-link Mixxx:out_2 "ardour:Deck2/audio_in 1"
pw-link Mixxx:out_3 "ardour:Deck2/audio_in 2"
pw-link Mixxx:out_4 "ardour:Deck3/audio_in 1"
pw-link Mixxx:out_5 "ardour:Deck3/audio_in 2"
pw-link Mixxx:out_6 "ardour:Deck4/audio_in 1"
pw-link Mixxx:out_7 "ardour:Deck4/audio_in 2"

# Setup recording from external mixer into Ardour
# pw-link "alsa_input.usb-BEHRINGER_UMC204HD_192k-00.pro-input-0:capture_AUX0" "ardour:Mixer Record/audio_in 1"
# pw-link "alsa_input.usb-BEHRINGER_UMC204HD_192k-00.pro-input-0:capture_AUX1" "ardour:Mixer Record/audio_in 2"

# Setup Ardour outputs to sound cards
# pw-link "ardour:Deck1/audio_out 1" "alsa_output.usb-ALLEN_HEATH_LTD._XONE_K2-00.analog-surround-40:playback_RL"
# pw-link "ardour:Deck1/audio_out 2" "alsa_output.usb-ALLEN_HEATH_LTD._XONE_K2-00.analog-surround-40:playback_RR"
# pw-link "ardour:Deck2/audio_out 1" "alsa_output.usb-ALLEN_HEATH_LTD._XONE_K2-00.analog-surround-40:playback_FL"
# pw-link "ardour:Deck2/audio_out 2" "alsa_output.usb-ALLEN_HEATH_LTD._XONE_K2-00.analog-surround-40:playback_FR"
# pw-link "ardour:Deck3/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_2_3__sink:playback_FL"
# pw-link "ardour:Deck3/audio_out 2" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_2_3__sink:playback_FR"
# pw-link "ardour:Deck4/audio_out 1" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_0_1__sink:playback_FL"
# pw-link "ardour:Deck4/audio_out 2" "alsa_output.usb-BEHRINGER_UMC204HD_192k-00.HiFi__umc204hd_stereo_out_U192k_0_0_1__sink:playback_FR"

# MIDI Connections

# Clean up MIDI connections

# pw-link -d "Midi-Bridge:Midi Through:(capture_0) Midi Through Port-0" "ardour:MTC in"
# pw-link -d "Midi-Bridge:Midi Through:(capture_0) Midi Through Port-0" "ardour:physical_midi_input_monitor_enable"
# pw-link -d $xonek2_midi_out "ardour:physical_midi_input_monitor_enable"
# pw-link -d $midi_fighter_out "ardour:physical_midi_input_monitor_enable"
# pw-link -d $midi_fighter_out "ardour:MTC in"
# pw-link -d $umc204_midi_out "ardour:physical_midi_input_monitor_enable"
# pw-link -d $umc204_midi_out "ardour:MTC in"
# pw-link -d $audio8_midi_out "ardour:physical_midi_input_monitor_enable"

# Setup MIDI connections

pw-link $xonek2_midi_out $midi_thru_in
pw-link $xonek2_midi_out $umc204_midi_in

pw-link $midi_fighter_out $midi_thru_in
pw-link $midi_fighter_out $umc204_midi_in

pw-link $umc204_midi_out $midi_clock_in
pw-link $umc204_midi_out $umc204_midi_in

pw-link $midi_thru_out $midi_control_in

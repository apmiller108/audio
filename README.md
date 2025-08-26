# Audio Production Environment Scripts

This repository contains a collection of scripts and configuration files for setting up and managing an audio production environment on Linux. The scripts are designed to work with JACK, PipeWire, Mixxx, and Ardour.

## Prerequisites

Before using these scripts, you will need to have the following software installed:

*   [JACK Audio Connection Kit](https://jackaudio.org/)
*   [PipeWire](https://pipewire.org/)
*   [Mixxx](https://mixxx.org/)
*   [Ardour](https://ardour.org/)
*   [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/)

## Usage

The scripts in this repository can be used to start and stop the JACK audio server, manage JACK connections, and launch Mixxx and Ardour with specific configurations.

### JACK

*   `jack_startup.sh`: Starts the JACK audio server.
*   `jack_shutdown.sh`: Stops the JACK audio server.
*   `jack_connections.sh`: A script for managing JACK connections. (The user will need to fill in the details of how this script works).

### PipeWire

*   `pipewire_mixxx_startup.sh`: Starts Mixxx with PipeWire.
*   `config/pipewire/`: Contains configuration files for PipeWire.
*   `config/wireplumber/`: Contains configuration files for WirePlumber. Lua scripts to configure various audio interfaces so they can work together.

- Symlink the pipewire config files to `~/.config/pipewire/`
- Symlink the wireplumber lua scripts to `~/.config/wireplumber/main.lua.d/`

#### A note about the Lua scripts
The Lua scripts in the `config/wireplumber/` directory are used to configure
WirePlumber to manage audio devices and nodes (streams) and their properties
(eg, latency, sample rate, etc). The provided scripts include configurations for
various audio interfaces such as Behringer UMC204, Allen & Heath Xone:K2 and the
Native Instruments Audio DJ 8.

This is the issue I had when using two audio interfaces at the same time (the
outputs) with Bitwig: One of them would have the dredded pops and clicks. I'm
not entirely sure why this happened, but after experimenting with various
settings, I found that setting the `clock.name` property to the same value for
both devices resolved the issue.

I believe this effictely disabled Pipewire's adaptive resampling which maybe was
causing the the proplem because it was having to resample to account for the
different hardware clocks.

From https://docs.pipewire.org/page_man_pipewire-props_7.html these two excerpts seem relevant:

>  Source, sinks, capture and playback streams contain a high quality adaptive resampler. It uses sinc based resampling with linear interpolation of filter banks to perform arbitrary resample factors. The resampler is activated in the following cases:
>  - The hardware of a device node does not support the graph samplerate. Resampling will occur from the graph samplerate to the hardware samplerate.
>  - The hardware clock of a device does not run at the same speed as the graph clock and adaptive resampling is required to match the clocks.
>  - A stream does not have the same samplerate as the graph and needs to be resampled.
>  - An application wants to activate adaptive resampling in a stream to make it match some other clock.
> PipeWire performs most of the sample conversions and resampling in the client (Or in the case of the PulseAudio server, in the pipewire-pulse server that creates the streams). This ensures all the conversions are offloaded to the clients and the server can deal with one single format for performance reasons.

> clock.name # string
>   The name of the clock. This name is auto generated from the card index and stream direction. Devices with the same clock name will not use a resampler to align the clocks. This can be used to link devices together with a shared word clock.
>
>   In Pro Audio mode, nodes from the same device are assumed to have the same clock and no resampling will happen when linked together. So, linking a capture port to a playback port will not use any adaptive resampling in Pro Audio mode.
>
>   In Non Pro Audio profile, no such assumption is made and adaptive resampling is done in all cases by default. This can also be disabled by setting the same clock.name on the nodes.

#### Tools
- `wpctl status`: to list devices
- `wpctl inspect {{device_id}}`: to inspect a given device and it's properties
- `pw-top`: to monitor PipeWire activity
- `pactl list`: to list PulseAudio (PipeWire) sinks and sources
- `systemctl --user restart pipewire pipewire-pulse wireplumber`: to restart PipeWire and WirePlumber services

### Mixxx
*   `mixxx_4_decks_ardour_midi_bindings.map`: A MIDI mapping file for using Mixxx with Ardour.

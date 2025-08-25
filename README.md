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
*   `config/wireplumber/`: Contains configuration files for WirePlumber.

- Symlink the pipewire config files to ~~/.config/pipewire/~
- Symlink the wireplumber lua scripts to ~~/.config/wireplumber/main.lua.d/~

### Mixxx

*   `mixxx_4_decks_ardour_midi_bindings.map`: A MIDI mapping file for using Mixxx with Ardour.

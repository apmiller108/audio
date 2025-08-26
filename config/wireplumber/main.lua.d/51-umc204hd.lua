-- Symlink this file to ~/.config/wireplumber/main.lua.d/ and restart
-- WirePlumber to apply the custom rules. (see README.md for details)
-- Rule for the card device
card_rule = {
  matches = {
    {
      { "device.name", "equals", "alsa_card.usb-BEHRINGER_UMC204HD_192k-00" },
    },
  },
  apply_properties = {
    ["device.nick"] = "UMC204HD (customized)",
    ["audio.rate"] = 48000,
    ["api.alsa.period-size"] = 256,
    ["api.alsa.period-num"] = 3,
  },
}

-- Rule for nodes (streams) from this device
node_rule = {
  matches = {
    {
      { "node.name", "matches", "alsa_output.usb-BEHRINGER_UMC204HD_192k-00*" },
    }
  },
  apply_properties = {
    ["audio.rate"] = 48000,
    ["clock.name"] = "shared-pro-clock",
  },
}

table.insert(alsa_monitor.rules, card_rule)
table.insert(alsa_monitor.rules, node_rule)

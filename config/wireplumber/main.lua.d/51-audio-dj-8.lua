-- Rule for the card device
card_rule = {
  matches = {
    {
      { "device.name", "equals", "alsa_card.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00" },
    },
  },
  apply_properties = {
    ["device.nick"] = "Audio 8 DJ (customized)",
    ["audio.rate"] = 48000,
    ["api.alsa.period-size"] = 256,
    ["api.alsa.period-num"] = 3,
  },
}

-- Rule for nodes (streams) from this device
node_rule = {
  matches = {
    {
      { "node.name", "matches", "alsa_output.usb-Native_Instruments_Audio_8_DJ_SN-KNKYCDU9YU-00*" },
    }
  },
  apply_properties = {
    ["audio.rate"] = 48000,
    ["clock.name"] = "shared-pro-clock",
  },
}

table.insert(alsa_monitor.rules, card_rule)
table.insert(alsa_monitor.rules, node_rule)

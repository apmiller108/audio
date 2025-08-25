-- Rule for the card device
card_rule = {
  matches = {
    {
      { "device.name", "equals", "alsa_card.usb-ALLEN_HEATH_LTD._XONE_K2-00" },
    },
  },
  apply_properties = {
    ["device.nick"] = "XONE:K2 (customized)",
    ["audio.rate"] = 48000,
    ["api.alsa.period-size"] = 256,
    ["api.alsa.period-num"] = 3,
  },
}

-- Rule for nodes (streams) from this device
node_rule = {
  matches = {
    {
      { "node.name", "matches", "alsa_output.usb-ALLEN_HEATH_LTD._XONE_K2-00.*" },
    }
  },
  apply_properties = {
    ["audio.rate"] = 48000,
    ["api.alsa.period-size"] = 256,
    ["api.alsa.period-num"] = 3,
  },
}

table.insert(alsa_monitor.rules, card_rule)
table.insert(alsa_monitor.rules, node_rule)

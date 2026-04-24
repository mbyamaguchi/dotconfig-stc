local wezterm = require 'wezterm'

local config = wezterm.config_builder()


config.automatically_reload_config = true

config.font_size = 11.0
config.font = wezterm.font("Source Han Code JP", {weight = "Regular", stretch="Normal", style = "Normal"})

config.use_ime = true
config.window_background_opacity = 0.8
config.show_tabs_in_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true

config.color_scheme = "iTerm2 Tango Dark"

return config

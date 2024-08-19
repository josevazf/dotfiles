-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Config settings
config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 12
config.cell_width = 1.0
config.enable_tab_bar = false
config.color_scheme = "Apple System Colors"
config.window_decorations = "RESIZE"

-- config.window_background_opacity = 0.8
-- config.macos_window_background_blur = 10

return config

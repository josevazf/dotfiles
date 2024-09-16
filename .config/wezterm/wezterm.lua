-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Config settings
config.font = wezterm.font("MesloLGS Nerd Font")
config.font_size = 12
config.cell_width = 1.0
config.enable_tab_bar = false
config.color_scheme_dirs = { "~/.config/wezterm/colors/" }
config.color_scheme = "nordic"
-- config.color_schemes = "Pnevma"
-- config.color_scheme = "Nord (Gogh)"
-- config.color_scheme = "N0tch2k"
-- config.color_scheme = "Flatland"
-- config.color_scheme = "flexoki-dark"
-- config.color_scheme = "Ashes (dark) (terminal.sexy)"
-- config.color_scheme = "Apprentice (Gogh)"

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.95
config.macos_window_background_blur = 10

config.window_padding = {
	left = 5,
	right = 5,
	top = 5,
	bottom = 0,
}

return config

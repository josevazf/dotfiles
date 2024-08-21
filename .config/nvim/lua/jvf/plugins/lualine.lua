return {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local lualine = require("lualine")
        local lazy_status = require("lazy.status") -- to configure lazy pending updates count

        lualine.setup({
            options = {
                theme = "OceanicNext",
                component_separators = "|",
                section_separators = { left = "", right = "" },
            },
            sections = {
                sections = {
                    lualine_a = { { "mode", separator = { left = "" }, right_padding = 10 } },
                    lualine_b = { "filename", "branch" },
                    lualine_c = {
                        "datetime",
                        style = "default",
                    },
                    lualine_x = {
                        lazy_status.updates,
                        cond = lazy_status.has_updates,
                        color = { fg = "#ff9e64" },
                    },
                    lualine_y = { "filetype", "progress" },
                    lualine_z = {
                        { "location", separator = { right = "" } },
                    },
                },
                inactive_sections = {
                    lualine_a = { "filename" },
                    lualine_b = {},
                    lualine_c = {},
                    lualine_x = {},
                    lualine_y = {},
                    lualine_z = { "location" },
                },
            },
        })
    end,
}

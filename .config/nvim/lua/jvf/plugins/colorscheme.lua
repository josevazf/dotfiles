-- return {
--     "projekt0n/github-nvim-theme",
--     lazy = false,
--     priority = 1000,
--     config = function()
--         require("github-theme").setup({
--             --            specs = specs,
--             options = {
--                 dim_inactive = false,
--                 styles = {
--                     comments = "italic",
--                 },
--             },
--             groups = {
--                 all = {
--                     Normal = { bg = "none" },
--                     NormalNC = { bg = "none" },
--                     NvimTreeNormal = { bg = "none" },
--                 },
--             },
--         })
--         vim.cmd("colorscheme github_dark")
--         -- vim.cmd("colorscheme github_light")
--     end,
-- }

return {
    "AlexvZyl/nordic.nvim",
    branch = "dev",
    lazy = false,
    priority = 1000,
    config = function()
        require("nordic").setup({
            transparent = {
                bg = true,
                float = false,
            },
            cursorline = {
                "dark",
            },
            telescope = {
                style = "classic",
            },
        })
        require("nordic").load()
    end,
}

-- return {
--     "projekt0n/github-nvim-theme",
--     lazy = false,
--     priority = 1000,
--     config = function()
--         --        local specs = {
--         --            all = {
--         --                syntax = {
--         --                    conditional = keyword,
--         --                    operator = keyword,
--         --
--         --                }
--         --            }
--         --        }
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
    lazy = false,
    priority = 1000,
    config = function()
        --     require("nordic").setup({
        --         cursorline = {
        --             "dark",
        --         },
        --     })
        require("nordic").load()
        require("nordic").setup({
            cursorline = {
                "dark",
            },
        })
    end,
}

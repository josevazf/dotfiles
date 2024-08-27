return {
    "projekt0n/github-nvim-theme",
    lazy = false, -- make sure to load this during startup
    priority = 1000, -- make sure to load this before all the other plugins
    config = function()
        --        local specs = {
        --            all = {
        --                syntax = {
        --                    conditional = keyword,
        --                    operator = keyword,
        --
        --                }
        --            }
        --        }
        require("github-theme").setup({
            --            specs = specs,
            options = {
                dim_inactive = false,
                styles = {
                    comments = "italic",
                },
            },
        })
        vim.cmd("colorscheme github_dark")
        -- vim.cmd("colorscheme github_light")
    end,
}

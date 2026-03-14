---@module "neominimap.config.meta"
return {
    "Isrothy/neominimap.nvim",
    version = "v3.x.x",
    lazy = false, -- NOTE: NO NEED to Lazy load
    -- Optional. You can alse set your own keybindings
    keys = {
        -- Global Minimap Controls
        { "<leader>nm", "<cmd>Neominimap Toggle<cr>", desc = "Toggle global minimap" },
        { "<leader>no", "<cmd>Neominimap Enable<cr>", desc = "Enable global minimap" },
        { "<leader>nc", "<cmd>Neominimap Disable<cr>", desc = "Disable global minimap" },
        { "<leader>nr", "<cmd>Neominimap Refresh<cr>", desc = "Refresh global minimap" },

        -- Window-Specific Minimap Controls
        { "<leader>nwt", "<cmd>Neominimap WinToggle<cr>", desc = "Toggle minimap for current window" },
        { "<leader>nwr", "<cmd>Neominimap WinRefresh<cr>", desc = "Refresh minimap for current window" },
        { "<leader>nwo", "<cmd>Neominimap WinEnable<cr>", desc = "Enable minimap for current window" },
        { "<leader>nwc", "<cmd>Neominimap WinDisable<cr>", desc = "Disable minimap for current window" },

        -- Tab-Specific Minimap Controls
        { "<leader>ntt", "<cmd>Neominimap TabToggle<cr>", desc = "Toggle minimap for current tab" },
        { "<leader>ntr", "<cmd>Neominimap TabRefresh<cr>", desc = "Refresh minimap for current tab" },
        { "<leader>nto", "<cmd>Neominimap TabEnable<cr>", desc = "Enable minimap for current tab" },
        { "<leader>ntc", "<cmd>Neominimap TabDisable<cr>", desc = "Disable minimap for current tab" },

        -- Buffer-Specific Minimap Controls
        { "<leader>nbt", "<cmd>Neominimap BufToggle<cr>", desc = "Toggle minimap for current buffer" },
        { "<leader>nbr", "<cmd>Neominimap BufRefresh<cr>", desc = "Refresh minimap for current buffer" },
        { "<leader>nbo", "<cmd>Neominimap BufEnable<cr>", desc = "Enable minimap for current buffer" },
        { "<leader>nbc", "<cmd>Neominimap BufDisable<cr>", desc = "Disable minimap for current buffer" },

        ---Focus Controls
        { "<leader>nf", "<cmd>Neominimap Focus<cr>", desc = "Focus on minimap" },
        { "<leader>nu", "<cmd>Neominimap Unfocus<cr>", desc = "Unfocus minimap" },
        { "<leader>ns", "<cmd>Neominimap ToggleFocus<cr>", desc = "Switch focus on minimap" },
    },
    init = function()
        -- The following options are recommended when layout == "float"
        vim.opt.wrapmargin = 45
        vim.opt.wrap = true
        vim.opt.sidescrolloff = 0 -- Set a large value
        vim.opt.scrolloff = 10  -- Optional: vertical scroll margin
        vim.opt.linebreak = true        -- Break at word boundaries
        vim.opt.breakindent = true      -- Indent wrapped lines
        vim.opt.showbreak = "↳ "        -- Visual indicator for wrapped lines
        -- vim.opt.colorcolumn = "80"

        --- Put your configuration here
        ---@type Neominimap.UserConfig
        vim.g.neominimap = {
            auto_enable = true,
            layout = "float",
            float = { 
                minimap_width = 12,
                window_border = vim.fn.has("nvim-0.11") == 2 and vim.opt.winborder:get() or "rounded",
                margin = { right = 1, top = 0, bottom = 0 },
            },
            render = {
                wrap = true,
            },
        }
    end,
}

-- -- -@module "neominimap.config.meta"
-- return {
--     "Isrothy/neominimap.nvim",
--     version = "v3.x.x",
--     lazy = false, -- NOTE: NO NEED to Lazy load
--     -- Optional. You can alse set your own keybindings
--     keys = {
--         -- Global Minimap Controls
--         { "<leader>nm", "<cmd>Neominimap Toggle<cr>", desc = "Toggle global minimap" },
--         { "<leader>no", "<cmd>Neominimap Enable<cr>", desc = "Enable global minimap" },
--         { "<leader>nc", "<cmd>Neominimap Disable<cr>", desc = "Disable global minimap" },
--         { "<leader>nr", "<cmd>Neominimap Refresh<cr>", desc = "Refresh global minimap" },
--
--         -- Window-Specific Minimap Controls
--         { "<leader>nwt", "<cmd>Neominimap WinToggle<cr>", desc = "Toggle minimap for current window" },
--         { "<leader>nwr", "<cmd>Neominimap WinRefresh<cr>", desc = "Refresh minimap for current window" },
--         { "<leader>nwo", "<cmd>Neominimap WinEnable<cr>", desc = "Enable minimap for current window" },
--         { "<leader>nwc", "<cmd>Neominimap WinDisable<cr>", desc = "Disable minimap for current window" },
--
--         -- Tab-Specific Minimap Controls
--         { "<leader>ntt", "<cmd>Neominimap TabToggle<cr>", desc = "Toggle minimap for current tab" },
--         { "<leader>ntr", "<cmd>Neominimap TabRefresh<cr>", desc = "Refresh minimap for current tab" },
--         { "<leader>nto", "<cmd>Neominimap TabEnable<cr>", desc = "Enable minimap for current tab" },
--         { "<leader>ntc", "<cmd>Neominimap TabDisable<cr>", desc = "Disable minimap for current tab" },
--
--         -- Buffer-Specific Minimap Controls
--         { "<leader>nbt", "<cmd>Neominimap BufToggle<cr>", desc = "Toggle minimap for current buffer" },
--         { "<leader>nbr", "<cmd>Neominimap BufRefresh<cr>", desc = "Refresh minimap for current buffer" },
--         { "<leader>nbo", "<cmd>Neominimap BufEnable<cr>", desc = "Enable minimap for current buffer" },
--         { "<leader>nbc", "<cmd>Neominimap BufDisable<cr>", desc = "Disable minimap for current buffer" },
--
--         ---Focus Controls
--         { "<leader>nf", "<cmd>Neominimap Focus<cr>", desc = "Focus on minimap" },
--         { "<leader>nu", "<cmd>Neominimap Unfocus<cr>", desc = "Unfocus minimap" },
--         { "<leader>ns", "<cmd>Neominimap ToggleFocus<cr>", desc = "Switch focus on minimap" },
--     },
--     init = function()
--         -- The following options are recommended when layout == "float"
--         vim.opt.wrap = true
--         -- vim.opt.wrapmargin = 12
--         vim.opt.sidescrolloff = 36 -- Set a large value
--
--         --- Put your configuration here
--         ---@type Neominimap.UserConfig
--         vim.g.neominimap = {
--             auto_enable = true,
--             -- winopt = {
--             --     winhighlight = table.concat({
--             --         "Normal:NeominimapBackground",
--             --         "FloatBorder:NeominimapBorder",
--             --         "CursorLine:NeominimapCursorLine",
--             --         "CursorLineNr:NeominimapCursorLineNr",
--             --         "CursorLineSign:NeominimapCursorLineSign",
--             --         "CursorLineFold:NeominimapCursorLineFold",
--             --     }, ","),
--             --     wrap = true,
--             --     foldcolumn = "0",
--             --     signcolumn = "auto",
--             --     number = false,
--             --     relativenumber = false,
--             --     scrolloff = config.current_line_position == "center" and 99999 or 0,
--             --     sidescrolloff = 0,
--             --     winblend = 0,
--             --     cursorline = true,
--             --     spell = false,
--             --     list = false,
--             --     fillchars = "eob: ",
--             --     winfixwidth = true,
--             -- },
--             float = {
--                 minimap_width = 12, ---@type integer
--
--                 --- If set to nil, there is no maximum height restriction
--                 --- @type integer
--                 max_minimap_height = nil,
--
--                 margin = {
--                     right = 0, ---@type integer
--                     top = 0, ---@type integer
--                     bottom = 0, ---@type integer
--                 },
--                 z_index = 1, ---@type integer
--
--                 --- Border style of the floating window.
--                 --- Accepts all usual border style options (e.g., "single", "double")
--                 --- @type string | string[] | [string, string][]
--                 window_border = vim.fn.has("nvim-0.11") == 1 and vim.opt.winborder:get() or "single",
--
--                 -- When true, the floating window will be recreated when you close it.
--                 -- When false, the minimap will be disabled for the current tab when you close the minimap window.
--                 persist = true, ---@type boolean
--             },
--         }
--     end,
--
-- }


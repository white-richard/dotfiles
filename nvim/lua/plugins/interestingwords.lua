return {
  "Mr-LLLLL/interestingwords.nvim",
  event = "VeryLazy",
  config = function()
    local iw = require("interestingwords")

    --your custom setup
    iw.setup{
      colors = { '#8be9fd', '#50fa7b', '#ff79c6', '#ffb86c', '#bd93f9', '#ff5555' },
      search_key = "<leader>s",          -- toggle highlight
      cancel_search_key = "<leader>S",   -- remove highlight
      color_key = "<leader>c",           -- add a color
      cancel_color_key = "<leader>C",    -- remove color
    }

    -- enable mouse in normal mode
    if not string.find(vim.o.mouse, "n", 1, true) then
      vim.o.mouse = vim.o.mouse .. "n"
    end

    -- double-click triggers <Leader>s
    vim.keymap.set("n", "<2-LeftMouse>", "<Leader>s", { remap = true, silent = true, desc = "Highlight word (double-click)" })
  end,
}


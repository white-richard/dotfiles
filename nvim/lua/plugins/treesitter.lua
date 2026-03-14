return { -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    local parsers = {
      'lua',
      'python',
      'javascript',
      'typescript',
      'vimdoc',
      'vim',
      'regex',
      'terraform',
      'sql',
      'dockerfile',
      'toml',
      'json',
      'java',
      'groovy',
      'go',
      'gitignore',
      'graphql',
      'yaml',
      'make',
      'cmake',
      'markdown',
      'markdown_inline',
      'bash',
      'tsx',
      'css',
      'html',
    }

    local ts = require 'nvim-treesitter'

    -- Optional: only needed if you want a custom install dir etc.
    -- ts.setup {
    --   -- install_dir = vim.fn.stdpath("data") .. "/site",
    -- }

    ts.install(parsers) -- no-op if already installed

    -- Enable TS highlighting per filetype (Neovim builtin)
    vim.api.nvim_create_autocmd('FileType', {
      pattern = parsers, -- or { "*" } if you want it everywhere
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })

    -- Optional: folds (Neovim builtin)
    -- Note: fold are dumb
    vim.opt.foldenable = false
    -- vim.wo.foldmethod = "manual"
    -- vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,

  -- LEGACY TREESITTER API --

  -- main = 'nvim-treesitter.configs', -- Sets main module to use for opts
  -- -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
  -- opts = {
  --   ensure_installed = {
  --     'lua',
  --     'python',
  --     'javascript',
  --     'typescript',
  --     'vimdoc',
  --     'vim',
  --     'regex',
  --     'terraform',
  --     'sql',
  --     'dockerfile',
  --     'toml',
  --     'json',
  --     'java',
  --     'groovy',
  --     'go',
  --     'gitignore',
  --     'graphql',
  --     'yaml',
  --     'make',
  --     'cmake',
  --     'markdown',
  --     'markdown_inline',
  --     'bash',
  --     'tsx',
  --     'css',
  --     'html',
  --   },
  --   -- Autoinstall languages that are not installed
  --   auto_install = true,
  --   highlight = {
  --     enable = true,
  --     -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
  --     --  If you are experiencing weird indenting issues, add the language to
  --     --  the list of additional_vim_regex_highlighting and disabled languages for indent.
  --     additional_vim_regex_highlighting = { 'ruby' },
  --   },
  --   indent = { enable = true, disable = { 'ruby' } },
  -- },
  -- There are additional nvim-treesitter modules that you can use to interact
  -- with nvim-treesitter. You should go explore a few and see what interests you:
  --
  --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
}

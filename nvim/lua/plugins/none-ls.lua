return {
  'nvimtools/none-ls.nvim',
  dependencies = {
    'nvimtools/none-ls-extras.nvim',
    'jayp0521/mason-null-ls.nvim', -- ensure dependencies are installed
  },
  config = function()
    local null_ls = require 'null-ls'
    local formatting = null_ls.builtins.formatting -- to setup formatters
    local diagnostics = null_ls.builtins.diagnostics -- to setup linters

    -- Formatters & linters for mason to install
    require('mason-null-ls').setup {
      ensure_installed = {
        'prettier', -- ts/js formatter
        'eslint_d', -- ts/js linter
        'shfmt', -- Shell formatter
        'checkmake', -- linter for Makefiles
        -- 'stylua', -- lua formatter; Already installed via Mason
        -- 'ruff', -- Python linter and formatter; Already installed via Mason
      },
      automatic_installation = true,
    }

    -- tex-fmt has no none-ls builtin. Zed formats LaTeX with `tex-fmt --stdin`,
    -- so register the same command here.
    local tex_fmt = {
      name = 'tex_fmt',
      method = null_ls.methods.FORMATTING,
      filetypes = { 'tex', 'latex', 'plaintex', 'bib' },
      generator = require('null-ls.helpers').formatter_factory {
        command = 'tex-fmt',
        args = { '--stdin' },
        to_stdin = true,
      },
    }

    local sources = {
      diagnostics.checkmake,
      -- Zed's default formatter is "auto": prettier whenever prettier supports
      -- the language, otherwise the primary language server. This list mirrors
      -- prettier's coverage in Zed so the two editors agree.
      formatting.prettier.with {
        filetypes = {
          'html',
          'css',
          'scss',
          'less',
          'json',
          'jsonc',
          'yaml',
          'markdown',
          'markdown.mdx',
          'graphql',
          'javascript',
          'javascriptreact',
          'typescript',
          'typescriptreact',
          'svelte',
        },
      },
      formatting.stylua,
      formatting.shfmt.with { args = { '-i', '4' } },
      formatting.terraform_fmt,
      tex_fmt,
      -- `ruff check --fix` then `ruff format`, which is what Zed's
      -- source.fixAll + source.organizeImports + format pipeline resolves to.
      require 'none-ls.formatting.ruff',
      require 'none-ls.formatting.ruff_format',
    }

    -- Neovim's synchronous format path applies EVERY attached client's edits in
    -- sequence, so a buffer with both null-ls and a language server that
    -- advertises formatting gets formatted twice and the last one silently
    -- wins. Zed always runs exactly one formatter. This filter does the same:
    -- prefer null-ls where it has a source for the buffer, otherwise fall back
    -- to the language server (typst/tinymist, and anything added later).
    local function format_buffer(bufnr)
      local has_null_ls = false
      for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, method = 'textDocument/formatting' }) do
        if client.name == 'null-ls' then
          has_null_ls = true
          break
        end
      end

      vim.lsp.buf.format {
        bufnr = bufnr,
        async = false,
        filter = function(client)
          if has_null_ls then
            return client.name == 'null-ls'
          end
          return true
        end,
      }
    end

    -- One global hook rather than one registered from null-ls's on_attach:
    -- that only fired for buffers null-ls itself attached to, so a buffer
    -- formatted purely by a language server (typst) never got formatted at all.
    local augroup = vim.api.nvim_create_augroup('LspFormatting', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = augroup,
      callback = function(args)
        format_buffer(args.buf)
      end,
    })

    null_ls.setup {
      -- debug = true, -- Enable debug mode. Inspect logs with :NullLsLog.
      sources = sources,
    }
  end,
}

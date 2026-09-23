local function copy_path(state, modifier)
  local path = vim.fn.fnamemodify(state.tree:get_node():get_id(), modifier)
  vim.fn.setreg('+', path)
  vim.notify('Copied ' .. path)
end

local function git_run(args, notify)
  vim.system(vim.list_extend({ 'git' }, args), { text = true }, function(res)
    vim.schedule(function()
      if notify or res.code ~= 0 then
        vim.notify(vim.trim(res.stdout .. res.stderr), res.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
      end
      require('neo-tree.events').fire_event 'git_event'
    end)
  end)
end

return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    'MunifTanjim/nui.nvim',
    '3rd/image.nvim', -- Optional image support in preview window: See `# Preview Mode` for more information
    {
      's1n7ax/nvim-window-picker',
      version = '2.*',
      config = function()
        require('window-picker').setup {
          filter_rules = {
            include_current_win = false,
            autoselect_one = true,
            -- filter using buffer options
            bo = {
              -- if the file type is one of following, the window will be ignored
              filetype = { 'neo-tree', 'neo-tree-popup', 'notify' },
              -- if the buffer type is one of following, the window will be ignored
              buftype = { 'terminal', 'quickfix' },
            },
          },
        }
      end,
    },
  },
  config = function()
    require('neo-tree').setup {
      sources = { 'filesystem', 'git_status', 'document_symbols' },
      default_source = 'last', -- <leader>b reopens whichever panel was last used
      close_if_last_window = false, -- Close Neo-tree if it is the last window left in the tab
      popup_border_style = 'rounded',
      enable_git_status = true,
      enable_diagnostics = true,
      -- enable_normal_mode_for_inputs = false,                             -- Enable normal mode for input dialogs.
      open_files_do_not_replace_types = { 'terminal', 'trouble', 'qf' }, -- when opening files, do not use windows containing these filetypes or buftypes
      sort_case_insensitive = false, -- used when sorting files and directories in the tree
      sort_function = nil, -- use a custom function for sorting files and directories in the tree
      -- sort_function = function (a,b)
      --       if a.type == b.type then
      --           return a.path > b.path
      --       else
      --           return a.type > b.type
      --       end
      --   end , -- this sorts files and directories descendantly
      default_component_configs = {
        container = {
          enable_character_fade = true,
        },
        indent = {
          indent_size = 2,
          padding = 1, -- extra padding on left hand side
          -- indent guides
          with_markers = true,
          indent_marker = '│',
          last_indent_marker = '└',
          highlight = 'NeoTreeIndentMarker',
          -- expander config, needed for nesting files
          with_expanders = nil, -- if nil and file nesting is enabled, will enable expanders
          expander_collapsed = '',
          expander_expanded = '',
          expander_highlight = 'NeoTreeExpander',
        },
        icon = {
          folder_closed = '',
          folder_open = '',
          folder_empty = '󰜌',
          -- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
          -- then these will never be used.
          default = '*',
          highlight = 'NeoTreeFileIcon',
        },
        modified = {
          symbol = '[+]',
          highlight = 'NeoTreeModified',
        },
        name = {
          trailing_slash = false,
          use_git_status_colors = true,
          highlight = 'NeoTreeFileName',
        },
        git_status = {
          symbols = {
            -- Change type
            added = '', -- or "✚", but this is redundant info if you use git_status_colors on the name
            modified = '', -- or "", but this is redundant info if you use git_status_colors on the name
            deleted = '✖', -- this can only be used in the git_status source
            renamed = '󰁕', -- this can only be used in the git_status source
            -- Status type
            untracked = '',
            ignored = '',
            unstaged = '󰄱',
            staged = '',
            conflict = '',
          },
        },
        -- If you don't want to use these columns, you can set `enabled = false` for each of them individually
        file_size = {
          enabled = true,
          required_width = 64, -- min width of window required to show this column
        },
        type = {
          enabled = true,
          required_width = 122, -- min width of window required to show this column
        },
        last_modified = {
          enabled = true,
          required_width = 88, -- min width of window required to show this column
        },
        created = {
          enabled = true,
          required_width = 110, -- min width of window required to show this column
        },
        symlink_target = {
          enabled = false,
        },
      },
      -- A list of functions, each representing a global custom command
      -- that will be available in all sources (if not overridden in `opts[source_name].commands`)
      -- see `:h neo-tree-custom-commands-global`
      commands = {
        copy_relative_path = function(state)
          copy_path(state, ':.')
        end,
        copy_absolute_path = function(state)
          copy_path(state, ':p')
        end,
        focus_parent = function(state)
          local parent = state.tree:get_node():get_parent_id()
          if parent then
            require('neo-tree.ui.renderer').focus_node(state, parent)
          end
        end,
        focus_editor = function()
          vim.cmd.wincmd 'p'
        end,
        -- Zed's project_panel::Open: open the file but stay in the panel
        open_keep_focus = function(state)
          local node = state.tree:get_node()
          state.commands.open(state)
          if node.type == 'file' then
            vim.cmd.wincmd 'p'
            vim.schedule(function()
              require('neo-tree.ui.renderer').focus_node(state, node:get_id())
            end)
          end
        end,
        system_open = function(state)
          vim.ui.open(state.tree:get_node():get_id())
        end,
        grep_in_dir = function(state)
          local node = state.tree:get_node()
          local dir = node.type == 'directory' and node:get_id() or vim.fn.fnamemodify(node:get_id(), ':h')
          require('telescope.builtin').live_grep { search_dirs = { dir }, prompt_title = 'Search in ' .. vim.fn.fnamemodify(dir, ':.') }
        end,
        git_open_diff = function(state)
          local node = state.tree:get_node()
          state.commands.open(state)
          if node.type == 'file' then
            vim.cmd 'Gvdiffsplit'
          end
        end,
        git_unstage_all = function()
          git_run { 'reset', '--quiet' }
        end,
        git_pull_rebase = function()
          git_run({ 'pull', '--rebase' }, true)
        end,
      },
      window = {
        position = 'left',
        width = 40,
        mapping_options = {
          noremap = true,
          nowait = true,
        },
        mappings = {
          ['<space>'] = 'none', -- space is the leader in panels, as in Zed
          ['<tab>'] = 'open_keep_focus',
          ['<2-LeftMouse>'] = 'open',
          ['<cr>'] = 'open',
          ['t'] = 'open',
          ['<esc>'] = 'focus_editor',
          ['P'] = { 'toggle_preview', config = { use_float = true } },
          ['h'] = 'close_node',
          ['l'] = 'open',
          ['<left>'] = 'close_node',
          ['<right>'] = 'open',
          ['v'] = 'open_vsplit',
          ['o'] = 'open_split',
          ['-'] = 'focus_parent',
          ['z'] = 'close_all_nodes',
          ['<C-S-c>'] = 'close_all_nodes',
          ['Y'] = 'copy_relative_path',
          ['gy'] = 'copy_absolute_path',
          ['q'] = 'close_window',
          ['<C-r>'] = 'refresh',
          ['?'] = 'show_help',
          ['<'] = 'prev_source',
          ['>'] = 'next_source',
          ['i'] = 'show_file_details',
        },
      },
      nesting_rules = {},
      filesystem = {
        filtered_items = {
          visible = false, -- when true, they will just be displayed differently than normal items
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false, -- only works on Windows for hidden files/directories
          hide_by_name = {
            '.DS_Store',
            'thumbs.db',
            'node_modules',
            '__pycache__',
            '.virtual_documents',
            '.git',
            '.python-version',
            '.venv',
          },
          hide_by_pattern = { -- uses glob style patterns
            --"*.meta",
            --"*/src/*/tsconfig.json",
          },
          always_show = { -- remains visible even if other settings would normally hide it
            --".gitignored",
          },
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            --".DS_Store",
            --"thumbs.db"
          },
          never_show_by_pattern = { -- uses glob style patterns
            --".null-ls_*",
          },
        },
        follow_current_file = {
          enabled = false, -- This will find and focus the file in the active buffer every time
          --               -- the current file is changed while the tree is open.
          leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
        },
        group_empty_dirs = false, -- when true, empty folders will be grouped together
        hijack_netrw_behavior = 'open_default', -- netrw disabled, opening a directory opens neo-tree
        -- in whatever position is specified in window.position
        -- "open_current",  -- netrw disabled, opening a directory opens within the
        -- window like netrw would, regardless of window.position
        -- "disabled",    -- netrw left alone, neo-tree does not handle opening dirs
        use_libuv_file_watcher = false, -- This will use the OS level file watchers to detect changes
        -- instead of relying on nvim autocmd events.
        window = {
          mappings = {
            -- Zed ProjectPanel (vim mode) + zed/keymap.json
            ['%'] = { 'add', config = { show_path = 'none' } },
            ['a'] = { 'add', config = { show_path = 'none' } },
            ['d'] = 'add_directory',
            ['A'] = 'add_directory',
            ['D'] = 'delete',
            ['R'] = 'rename',
            ['r'] = 'rename',
            ['<bs>'] = 'trash',
            ['<del>'] = 'trash',
            ['<S-del>'] = 'trash',
            [']c'] = 'next_git_modified',
            ['[c'] = 'prev_git_modified',
            ['/'] = 'grep_in_dir',
            ['s'] = 'system_open',
            -- Extras (Zed uses cmd-c/x/v, which Ghostty owns)
            ['y'] = 'copy_to_clipboard',
            ['x'] = 'cut_to_clipboard',
            ['p'] = 'paste_from_clipboard',
            ['c'] = 'copy',
            ['m'] = 'move',
            ['.'] = 'set_root',
            ['H'] = 'toggle_hidden',
            ['f'] = 'filter_on_submit',
            ['#'] = 'fuzzy_sorter',
            ['<c-x>'] = 'clear_filter',
            ['O'] = { 'show_help', nowait = false, config = { title = 'Order by', prefix_key = 'O' } },
            ['Oc'] = { 'order_by_created', nowait = false },
            ['Od'] = { 'order_by_diagnostics', nowait = false },
            ['Og'] = { 'order_by_git_status', nowait = false },
            ['Om'] = { 'order_by_modified', nowait = false },
            ['On'] = { 'order_by_name', nowait = false },
            ['Os'] = { 'order_by_size', nowait = false },
            ['Ot'] = { 'order_by_type', nowait = false },
            -- Shadow neo-tree's source defaults so the global maps above apply
            ['o'] = 'open_split',
            ['oc'] = 'none',
            ['od'] = 'none',
            ['og'] = 'none',
            ['om'] = 'none',
            ['on'] = 'none',
            ['os'] = 'none',
            ['ot'] = 'none',
          },
          fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
            ['<down>'] = 'move_cursor_down',
            ['<C-n>'] = 'move_cursor_down',
            ['<up>'] = 'move_cursor_up',
            ['<C-p>'] = 'move_cursor_up',
          },
        },

        commands = {}, -- Add a custom command or override a global one using the same function name
      },
      buffers = {
        follow_current_file = {
          enabled = true, -- This will find and focus the file in the active buffer every time
          --              -- the current file is changed while the tree is open.
          leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
        },
        group_empty_dirs = true, -- when true, empty folders will be grouped together
        show_unloaded = true,
        window = {
          mappings = {
            ['bd'] = 'buffer_delete',
            ['<bs>'] = 'navigate_up',
            ['.'] = 'set_root',
            ['o'] = { 'show_help', nowait = false, config = { title = 'Order by', prefix_key = 'o' } },
            ['oc'] = { 'order_by_created', nowait = false },
            ['od'] = { 'order_by_diagnostics', nowait = false },
            ['om'] = { 'order_by_modified', nowait = false },
            ['on'] = { 'order_by_name', nowait = false },
            ['os'] = { 'order_by_size', nowait = false },
            ['ot'] = { 'order_by_type', nowait = false },
          },
        },
      },
      git_status = {
        window = {
          mappings = {
            -- Zed GitPanel (vim mode) + zed/keymap.json
            ['x'] = 'git_toggle_file_stage',
            ['X'] = 'git_add_all',
            ['U'] = 'git_unstage_all',
            ['<bs>'] = 'git_revert_file',
            ['<del>'] = 'git_revert_file',
            ['<cr>'] = 'git_open_diff',
            ['gf'] = 'git_open_diff',
            ['i'] = 'git_commit',
            ['<C-g>'] = 'git_push',
            ['<C-S-o>'] = 'git_pull_rebase',
            ['ga'] = 'git_add_file',
            ['gu'] = 'git_unstage_file',
            ['gr'] = 'git_revert_file',
            ['gc'] = 'git_commit',
            ['gp'] = 'git_push',
            ['gg'] = 'none', -- default is commit_and_push; gg means top in Zed
            ['A'] = 'none',
            ['o'] = 'open_split',
            ['oc'] = 'none',
            ['od'] = 'none',
            ['om'] = 'none',
            ['on'] = 'none',
            ['os'] = 'none',
            ['ot'] = 'none',
          },
        },
      },
      document_symbols = {
        window = {
          mappings = {
            ['<cr>'] = 'jump_to_symbol',
            ['l'] = 'toggle_node',
            ['h'] = 'close_node',
          },
        },
      },
    }

    vim.cmd [[nnoremap \ :Neotree reveal<cr>]]
    vim.keymap.set('n', '<leader>ngs', ':Neotree focus git_status position=left<CR>', { noremap = true, silent = true }) -- open git status window
  end,
}

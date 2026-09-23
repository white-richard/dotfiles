-- Keymaps mirroring zed/keymap.json and Zed's defaults. The space binds are also
-- defined in Zed so both editors share one scheme.
local opts = { noremap = true, silent = true }

local function map(modes, lhs, rhs, desc)
  vim.keymap.set(modes, lhs, rhs, vim.tbl_extend('force', opts, { desc = desc }))
end

-- Ghostty sends cmd+key as <D-key>; tmux folds super into Meta, so bind both.
local function cmd(modes, key, rhs, desc)
  map(modes, '<D-' .. key .. '>', rhs, desc)
  map(modes, '<M-' .. key .. '>', rhs, desc)
end

-- Like Zed's *::ToggleFocus: jump into the panel, or back out if already there.
local function toggle_focus(source)
  if vim.bo.filetype == 'neo-tree' and vim.b.neo_tree_source == source then
    vim.cmd.wincmd 'p'
  else
    vim.cmd('Neotree focus source=' .. source .. ' position=left')
  end
end

local function telescope(picker, args)
  return function()
    require('telescope.builtin')[picker](args)
  end
end

-- Docks and panels
map('n', '<leader>j', '<cmd>ToggleTerm<CR>', 'Toggle bottom terminal')
cmd({ 'n', 'i', 't' }, 'j', '<cmd>ToggleTerm<CR>', 'Toggle bottom terminal')
map({ 'n', 'i', 't' }, '<C-`>', '<cmd>ToggleTerm<CR>', 'Toggle bottom terminal')
map('n', '<leader>b', '<cmd>Neotree toggle position=left<CR>', 'Toggle left dock')
cmd({ 'n', 'i', 't' }, 'b', '<cmd>Neotree toggle position=left<CR>', 'Toggle left dock')
map('n', '<leader>E', function()
  toggle_focus 'filesystem'
end, 'Toggle project panel focus')
map('n', '<leader>G', function()
  toggle_focus 'git_status'
end, 'Toggle git panel focus')
map('n', '<C-S-g>', function()
  toggle_focus 'git_status'
end, 'Toggle git panel focus')
map('n', '<leader>B', function()
  toggle_focus 'document_symbols'
end, 'Toggle outline panel focus')
map('n', '<C-S-c>', function()
  local state = require('neo-tree.sources.manager').get_state 'filesystem'
  if state.tree then
    require('neo-tree.sources.filesystem.commands').close_all_nodes(state)
  end
end, 'Collapse all project panel entries')
map('n', '<leader>d', '<cmd>Trouble diagnostics toggle<CR>', 'Diagnostics panel')

-- Pickers and search
map('n', '<leader>p', telescope 'find_files', 'File finder')
map('n', '<leader>F', telescope 'live_grep', 'Project search')
map('n', 'g/', telescope 'live_grep', 'Project search')
map('n', '<leader>H', function()
  require('grug-far').open()
end, 'Project search and replace')
map('n', '<leader>o', telescope('buffers', { sort_mru = true, ignore_current_buffer = true }), 'Tab switcher')

-- Editing
cmd({ 'n', 'i' }, 's', '<cmd>w<CR>', 'Save')
cmd('n', '/', function()
  require('Comment.api').toggle.linewise.current()
end, 'Toggle comment')
cmd('i', '/', function()
  require('Comment.api').toggle.linewise.current()
end, 'Toggle comment')
cmd('x', '/', "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", 'Toggle comment')
map('x', 'c', '"+d', 'Cut to system clipboard')
map('x', 'J', ":m '>+1<CR>gv=gv", 'Move line down')
map('x', 'K', ":m '<-2<CR>gv=gv", 'Move line up')
map('n', ']e', '<cmd>m .+1<CR>==', 'Move line down')
map('n', '[e', '<cmd>m .-2<CR>==', 'Move line up')
map('n', '<leader>;', function()
  vim.wo.number = not vim.wo.number
  vim.wo.relativenumber = vim.wo.number
end, 'Toggle line numbers')

-- Git
map('n', '<leader>gb', '<cmd>Gitsigns blame<CR>', 'Git blame')
map('n', "<leader>'", '<cmd>Gitsigns preview_hunk_inline<CR>', 'Toggle diff hunk')
map('n', ']c', function()
  if vim.wo.diff then
    vim.cmd.normal { ']c', bang = true }
  else
    require('gitsigns').nav_hunk 'next'
  end
end, 'Next hunk')
map('n', '[c', function()
  if vim.wo.diff then
    vim.cmd.normal { '[c', bang = true }
  else
    require('gitsigns').nav_hunk 'prev'
  end
end, 'Previous hunk')

-- Panes, terminals and items
map('n', '<leader>t', function()
  vim.cmd.terminal()
  vim.cmd.startinsert()
end, 'New center terminal')
map('n', '<leader>wh', '<cmd>leftabove vsplit<CR>', 'Split and move left')
map('n', '<leader>wj', '<cmd>belowright split<CR>', 'Split and move down')
map('n', '<leader>wk', '<cmd>aboveleft split<CR>', 'Split and move up')
map('n', '<leader>wl', '<cmd>belowright vsplit<CR>', 'Split and move right')
map('n', '<leader>\\', '<cmd>vsplit<CR>', 'Split right')
for i = 1, 9 do
  map('n', '<leader>' .. i, '<cmd>BufferLineGoToBuffer ' .. i .. '<CR>', 'Go to item ' .. i)
end
map('n', '<C-->', '<C-o>', 'Go back')
for key, dir in pairs { h = 'Left', j = 'Down', k = 'Up', l = 'Right' } do
  map('t', '<C-' .. key .. '>', '<cmd>TmuxNavigate' .. dir .. '<CR>', 'Move to pane ' .. dir:lower())
end

-- Diagnostics
local function diagnostic(count)
  return function()
    vim.diagnostic.jump { count = count, float = true }
  end
end
map('n', 'g]', diagnostic(1), 'Next diagnostic')
map('n', 'g[', diagnostic(-1), 'Previous diagnostic')
map('n', '<F8>', diagnostic(1), 'Next diagnostic')

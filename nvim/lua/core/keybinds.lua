-- Exports every keymap to keybinds/keymaps.js for keybinds/index.html.
-- Regenerates as plugins load, LSPs attach and panels open. :Keybinds opens the page.
local M = {}

local this_file = vim.uv.fs_realpath(debug.getinfo(1, 'S').source:sub(2))
local root = vim.fn.fnamemodify(this_file, ':h:h:h') -- nvim/ in the dotfiles repo
local page = root .. '/keybinds/index.html'
local data_file = root .. '/keybinds/keymaps.js'
local lazy_root = vim.fn.stdpath 'data' .. '/lazy/'
local runtime = vim.env.VIMRUNTIME or ''

local sources = {} -- "lhs\0desc" -> { path, line }
local contexts = {} -- buffer-local keymaps seen this session, by context name

local function norm(lhs)
  lhs = lhs:gsub('<[Ll]eader>', vim.g.mapleader or '\\'):gsub('<[Ll]ocal[Ll]eader>', vim.g.maplocalleader or '\\')
  return vim.fn.keytrans(vim.api.nvim_replace_termcodes(lhs, true, true, true))
end

-- The call site, skipping keymap helpers defined in the same file
local function caller()
  local path, line
  for level = 3, 30 do
    local info = debug.getinfo(level, 'Sl')
    if not info then
      break
    end
    local p = info.source:sub(1, 1) == '@' and vim.uv.fs_realpath(info.source:sub(2)) or nil
    if p and p ~= this_file and not p:find(runtime .. '/lua/vim/keymap.lua', 1, true) then
      if not path then
        path, line = p, info.currentline
      elseif p == path then
        line = info.currentline
      else
        break
      end
    elseif path then
      break
    end
  end
  return path, line
end

local function record(lhs, opts)
  if type(lhs) ~= 'string' then
    return
  end
  local path, line = caller()
  if path then
    pcall(function()
      sources[norm(lhs) .. '\0' .. ((opts or {}).desc or '')] = { path, line }
    end)
  end
end

local function lazy_owner(lhs)
  local ok, config = pcall(require, 'lazy.core.config')
  if not ok then
    return
  end
  for name, plugin in pairs(config.plugins) do
    if type(plugin.keys) == 'table' then
      for _, key in ipairs(plugin.keys) do
        local k = type(key) == 'table' and key[1] or key
        if type(k) == 'string' and norm(k) == lhs then
          return name
        end
      end
    end
  end
end

local function label(path, line, lhs)
  path = vim.uv.fs_realpath(path) or path
  if vim.startswith(path, root .. '/') then
    return { group = 'config', file = path:sub(#root + 2):gsub('^lua/', ''), line = line }
  elseif vim.startswith(path, lazy_root) then
    local name = path:sub(#lazy_root + 1):match '^[^/]+'
    if name == 'lazy.nvim' then
      name = lazy_owner(lhs) or name
    end
    return { group = 'plugin', name = name }
  elseif vim.startswith(path, runtime) then
    return { group = 'builtin' }
  end
  return { group = 'other', name = vim.fn.fnamemodify(path, ':~') }
end

local function source_of(map, lhs)
  local rec = sources[lhs .. '\0' .. (map.desc or '')]
  if rec then
    return label(rec[1], rec[2], lhs)
  end
  -- Vimscript maps know their script
  if (map.sid or 0) > 0 and (map.lnum or 0) > 0 then
    local info = vim.fn.getscriptinfo({ sid = map.sid })[1]
    if info then
      return label(info.name, map.lnum, lhs)
    end
  end
  return { group = 'builtin' }
end

local MODES = { 'n', 'x', 'o', 'i', 't', 'c' }

local function collect(get, filter)
  local entries, order = {}, {}
  for _, mode in ipairs(MODES) do
    for _, map in ipairs(get(mode)) do
      local lhs = vim.fn.keytrans(map.lhsraw or map.lhs)
      local skip = lhs:find('<Plug>', 1, true) or lhs:find('<SNR>', 1, true) or map.rhs == '<Nop>' or (map.desc or ''):find '^which%-key%-trigger'
      if not skip and (not filter or filter(map)) then
        local id = lhs .. '\0' .. (map.desc or map.rhs or '')
        local entry = entries[id]
        if not entry then
          entry = {
            lhs = lhs,
            desc = map.desc,
            rhs = not map.desc and map.rhs ~= '' and map.rhs or nil,
            modes = {},
            source = source_of(map, lhs),
          }
          entries[id] = entry
          table.insert(order, entry)
        end
        if not vim.tbl_contains(entry.modes, mode) then
          table.insert(entry.modes, mode)
        end
      end
    end
  end
  return order
end

local PANELS = {
  filesystem = 'File tree',
  git_status = 'Git panel',
  document_symbols = 'Outline panel',
}

local function context_of(buf)
  local ft, bt = vim.bo[buf].filetype, vim.bo[buf].buftype
  if ft == 'neo-tree' then
    local src = vim.b[buf].neo_tree_source
    return PANELS[src] or ('Sidebar: ' .. tostring(src))
  elseif bt == '' then
    return 'Code (language server attached)', function(map)
      return (map.desc or ''):find '^LSP: ' ~= nil
    end
  elseif ft ~= '' and ft ~= 'neominimap' then
    return ft
  end
end

local timer = vim.uv.new_timer()
local function schedule_export()
  timer:stop()
  timer:start(500, 0, vim.schedule_wrap(M.export))
end

local function capture(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local name, filter = context_of(buf)
  if not name then
    return
  end
  local maps = collect(function(mode)
    return vim.api.nvim_buf_get_keymap(buf, mode)
  end, filter)
  if #maps > 0 then
    for _, m in ipairs(maps) do
      m.desc = m.desc and m.desc:gsub('^LSP: ', '')
    end
    contexts[name] = { name = name, filetype = vim.bo[buf].filetype, seen = os.date '%Y-%m-%d', maps = maps }
    schedule_export()
  end
end

-- Contexts not visited this session keep their last export
local function previous_contexts()
  local fd = io.open(data_file, 'r')
  if not fd then
    return {}
  end
  local text = fd:read '*a'
  fd:close()
  local ok, data = pcall(vim.json.decode, (text:match '=%s*(%b{})'))
  return ok and type(data) == 'table' and data.contexts or {}
end

local last
function M.export()
  local merged = {}
  for _, ctx in ipairs(previous_contexts()) do
    if not contexts[ctx.name] then
      table.insert(merged, ctx)
    end
  end
  for _, ctx in pairs(contexts) do
    table.insert(merged, ctx)
  end
  table.sort(merged, function(a, b)
    return a.name < b.name
  end)

  local data = {
    leader = vim.g.mapleader,
    nvim = tostring(vim.version()),
    global = collect(vim.api.nvim_get_keymap),
    contexts = merged,
  }
  local body = vim.json.encode(data)
  if body == last then
    return
  end
  last = body
  data.generated = os.date '%Y-%m-%d %H:%M'
  vim.fn.mkdir(vim.fn.fnamemodify(data_file, ':h'), 'p')
  local fd = io.open(data_file, 'w')
  if fd then
    fd:write('// Generated by nvim/lua/core/keybinds.lua; do not edit.\nwindow.KEYBINDS = ', vim.json.encode(data), ';\n')
    fd:close()
  end
end

function M.setup()
  -- Record where each keymap is defined; Lua keymaps don't remember it themselves
  local keymap_set = vim.keymap.set
  vim.keymap.set = function(mode, lhs, rhs, opts)
    record(lhs, opts)
    return keymap_set(mode, lhs, rhs, opts)
  end
  local api_set = vim.api.nvim_set_keymap
  vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
    record(lhs, opts)
    return api_set(mode, lhs, rhs, opts)
  end

  local group = vim.api.nvim_create_augroup('keybinds-export', { clear = true })
  vim.api.nvim_create_autocmd('User', { group = group, pattern = { 'VeryLazy', 'LazyLoad' }, callback = schedule_export })
  vim.api.nvim_create_autocmd({ 'LspAttach', 'BufEnter' }, {
    group = group,
    callback = function(args)
      -- after the buffer's own mappings are set
      vim.schedule(function()
        capture(args.buf)
      end)
    end,
  })

  vim.api.nvim_create_user_command('Keybinds', function()
    M.export()
    vim.ui.open(page)
  end, { desc = 'Open the keybind reference page' })
end

return M

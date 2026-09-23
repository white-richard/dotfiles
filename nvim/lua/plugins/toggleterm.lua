-- Bottom terminal toggled by <leader>j / cmd+j (see core/zed.lua)
return {
  'akinsho/toggleterm.nvim',
  cmd = 'ToggleTerm',
  version = '*',
  opts = {
    size = 15,
    direction = 'horizontal',
    persist_mode = true,
  },
}

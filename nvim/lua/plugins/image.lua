-- sudo apt install imagemagick -y
-- sudo apt install poppler-utils -y

return {
  '3rd/image.nvim',
  opts = {
    backend = 'kitty',
    integrations = {
      neotree = {
        enabled = true,
      },
    },
    max_width = 100,
    max_height = 30,
    max_height_window_percentage = 40,
    window_overlap_clear_enabled = true,
  },
}

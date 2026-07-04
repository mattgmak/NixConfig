local is_vscode = vim.g.vscode ~= nil

return {
  '3rd/image.nvim',
  cond = not is_vscode,
  build = false,
  opts = {
    processor = 'magick_rock',
    backend = 'kitty',
    integrations = {
      markdown = {
        enabled = true,
        download_remote_images = true,
        only_render_image_at_cursor = false,
      },
    },
  },
}

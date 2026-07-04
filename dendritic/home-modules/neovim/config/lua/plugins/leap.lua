return {
  url = 'https://codeberg.org/andyg/leap.nvim',
  config = function(_, opts)
    vim.keymap.set({ 'n', 'x', 'o' }, '<BS>', '<Plug>(leap)')
    vim.keymap.set({ 'n', 'x', 'o' }, 'gh', '<Plug>(leap)')
    vim.keymap.set({ 'n' }, '<leader><BS>', '<Plug>(leap-anywhere)')
    vim.keymap.set({ 'n' }, '<leader>gh', '<Plug>(leap-anywhere)')
    vim.keymap.set(
      { 'n', 'o' },
      'gs',
      function()
        require('leap.remote').action({
          input = vim.fn.mode(true):match('o') and '' or 'v',
        })
      end
    )

    require('leap').opts.preview = function(ch0, ch1, ch2)
      return not (ch1:match('%s') or (ch0:match('%a') and ch1:match('%a') and ch2:match('%a')))
    end

    require('leap').opts.on_beacons = function(targets, _, _)
      for _, t in ipairs(targets) do
        if t.label and t.beacon then t.beacon[1] = 0 end
      end
    end

    vim.api.nvim_set_hl(0, 'LeapBackdrop', { link = 'Comment' })
  end,
}

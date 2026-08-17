local is_vscode = vim.g.vscode ~= nil

local function suppress_builtin_completion_ui()
  -- pi-nvim-bridge still wires the builtin floating menu when engine='blink'
  -- (upstream engine-wiring TODO). Skip attach so only blink.cmp renders completion.
  local ok, menu = pcall(require, 'pi-bridge.menu')
  if ok and type(menu.attach) == 'function' then menu.attach = function() end end

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'pi-prompt',
    callback = function(ev)
      local pi_ok, pi = pcall(require, 'pi-bridge')
      if not pi_ok or not pi.config or pi.config.engine ~= 'blink' then return end

      local buf = ev.buf
      pcall(
        function()
          vim.api.nvim_clear_autocmds({
            buffer = buf,
            group = 'pi-bridge',
            event = { 'InsertEnter', 'TextChangedI', 'CursorMovedI' },
          })
        end
      )

      -- Let blink.cmp own completion keymaps in pi-prompt buffers.
      for _, spec in ipairs({
        { 'i', '<Tab>' },
        { 'i', '<S-Tab>' },
        { 'i', '<C-N>' },
        { 'i', '<C-P>' },
        { 'i', '<Down>' },
        { 'i', '<Up>' },
        { 'i', '<C-E>' },
        { 'i', '<CR>' },
        { 'i', '<C-Y>' },
      }) do
        pcall(vim.keymap.del, spec[1], spec[2], { buffer = buf })
      end
    end,
  })
end

return {
  'dabstractor/pi-nvim-bridge',
  -- Pin to the vendored submodule (source of truth) instead of lazy's GitHub
  -- clone: the pi extension half loads from vendor/dabstractor/pi-nvim-bridge,
  -- so the nvim plugin must match that exact revision or the bridge halves
  -- drift apart (e.g. the shell-completion subsystem lives only in newer
  -- commits). Submodule bump + this dir both move together.
  dir = vim.fn.expand('$HOME') .. '/NixConfig/vendor/dabstractor/pi-nvim-bridge',
  lazy = false,
  cond = not is_vscode,
  config = function()
    -- Keep blink.cmp enabled in pi-prompt buffers; pi-bridge drives it via blink_source.
    vim.g.pi_bridge_suppress_engines = false
    require('pi-bridge').setup({ engine = 'blink' })
    suppress_builtin_completion_ui()
  end,
}

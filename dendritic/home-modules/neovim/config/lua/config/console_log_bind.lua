local M = {}

function M.setup()
  -- Bind to Visual Mode (x) using <leader>cl (console log)
  vim.keymap.set('x', '<leader>cl', function()
    -- 1. Get the current visual selection boundaries safely
    local mode = vim.api.nvim_get_mode().mode
    local start_pos = vim.fn.getpos('v')
    local end_pos = vim.fn.getpos('.')

    -- 2. Grab the actual text inside the selection
    local lines = vim.fn.getregion(start_pos, end_pos, { type = mode })
    local selected_text = table.concat(lines, ' ')

    -- Clean up any extra whitespaces or tabs from the selection
    selected_text = selected_text:gsub('%s+', ' '):match('^%s*(.-)%s*$')

    -- 3. Construct the inline console log string
    -- Example: (console.log("your_expr:", your_expr), your_expr)
    local replacement = string.format('(console.log(`%s:`, %s), %s)', selected_text, selected_text, selected_text)

    -- 4. Escape Visual Mode back to Normal Mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'x', false)

    -- 5. Calculate buffer replacement locations
    -- Adjust for Neovim's 0-indexed API (lines are 0-indexed, columns are 0-indexed bytes)
    local s_row, s_col = start_pos[2] - 1, start_pos[3] - 1
    local e_row, e_col = end_pos[2] - 1, end_pos[3]

    -- Reverse bounds if the selection was dragged backwards
    if s_row > e_row or (s_row == e_row and s_col > e_col) then
      s_row, e_row = e_row, s_row
      s_col, e_col = e_col, s_col
      -- Adjust end character index context
      s_col = s_col - 1
      e_col = e_col + 1
    end

    -- 6. Replace the old selection with the new inline log format
    vim.api.nvim_buf_set_text(0, s_row, s_col, e_row, e_col, { replacement })
  end, { desc = 'Wrap selection in inline console.log expression', buf = 0 })
end

return M

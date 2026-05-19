local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local conf = require "telescope.config".values

local M = {}

local live_multigrep = function(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local finder = finders.new_async_job {
    command_generator = function(prompt)
      if not prompt or prompt == "" then
        return nil
      end

      local pieces = vim.split(prompt, "  ")
      local args = { "rg" }
      if pieces[1] then
        table.insert(args, "-e")
        table.insert(args, pieces[1])
      end

      for i = 2, #pieces do
        local glob = pieces[i]
        if glob and glob ~= "" then
          table.insert(args, "-g")
          table.insert(args, glob)
        end
      end

      ---@diagnostic disable-next-line: deprecated
      return vim.tbl_flatten {
        args,
        { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
      }
    end,
    entry_maker = make_entry.gen_from_vimgrep(opts),
    cwd = opts.cwd,
  }

  pickers.new(opts, {
    debounce = 100,
    prompt_title = "Multi Grep",
    finder = finder,
    previewer = conf.grep_previewer(opts),
    sorter = require("telescope.sorters").empty(),
  }):find()
end

M.setup = function()
  local function get_selection()
    vim.cmd('noau normal! "vy"')
    local selection = vim.fn.getreg('v')
    local query = vim.trim((selection:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n+', ' '):gsub('%s+', ' ')))
    return query
  end
  vim.keymap.set({ 'n' }, '<leader>jg', function()
    live_multigrep()
  end, { desc = 'Find within files' })
  vim.keymap.set({ 'v' }, '<leader>jg', function()
    local query = vim.fn.escape(get_selection(), [[\/.*$^~[()]])
    live_multigrep({
      default_text = query,
    })
  end, { desc = 'Find within files' })
end

return M

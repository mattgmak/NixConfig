-- Global git hunk picker.
--
-- Enumerates hunks across ALL changed (tracked) files by parsing
-- `git diff HEAD -U0` directly. Each entry is ONE hunk; enter opens the file
-- at the hunk position; `s` stages, `u` unstages, `r` resets the file.
--
-- Preview = the FULL source file (syntax highlighted, scrollable), with the
-- selected hunk's lines highlighted octo-style: green bg for added lines,
-- red bg for deleted lines (deleted lines are shown inline at their position).
--
-- Picker construction mirrors telescope's builtin.git_branches
-- (finders.new_table + set_default_entry_mt + lazy display fn + file_sorter).
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local conf = require('telescope.config').values
local entry_display = require('telescope.pickers.entry_display')

local M = {}

------------------------------------------------------------------------------- diff parsing

local function run(cwd, args)
  local cmd = { 'git', '-C', cwd }
  for _, a in ipairs(args) do cmd[#cmd + 1] = a end
  local res = vim.system(cmd, { text = true }):wait()
  if res.code ~= 0 then
    vim.notify('[githunks] ' .. table.concat(cmd, ' ') .. ' failed: ' .. tostring(res.stderr), vim.log.levels.ERROR)
    return nil, tostring(res.stderr)
  end
  return res.stdout
end

local function repo_root(cwd)
  local out, err = run(cwd, { 'rev-parse', '--show-toplevel' })
  if not out then return nil, err end
  return (out:gsub('\n$', ''))
end

-- Parse `git diff -U0 HEAD` into hunks:
--   { file, oldstart, oldcount, newstart, newcount, lines = { {t='+'|'-', s=text} } }
local function parse_diff(text, cwd)
  local hunks = {}
  local current, hunk_file
  local prefix = cwd .. '/'

  for line in (text .. '\n'):gmatch('(.-)\n') do
    local head = line:sub(1, 4)
    if head == 'diff' or head == '--- ' then
      current = nil
      if head == '--- ' then current = false end -- saw file header, await +++
    elseif head == '+++ ' then
      current = nil
      hunk_file = (line:sub(5):gsub('^[ab]/', ''))
      if hunk_file:sub(1, #prefix) == prefix then hunk_file = hunk_file:sub(#prefix + 1) end
    elseif line:sub(1, 3) == '@@ ' then
      local olds, oldc, news, newc = line:match('@@ %-(%d+),?(%d*)%s+%+(%d+),?(%d*)%s+@@')
      if olds then
        current = {
          file = hunk_file,
          oldstart = tonumber(olds),
          oldcount = tonumber(oldc) or 1,
          newstart = tonumber(news),
          newcount = tonumber(newc) or 1,
          lines = {},
        }
        hunks[#hunks + 1] = current
      end
    elseif current then
      local op = line:sub(1, 1)
      if op == '+' or op == '-' then
        current.lines[#current.lines + 1] = { t = op, s = line:sub(2) }
      end
    end
  end
  return hunks
end

local function build_entries(root)
  local hunks = {}

  -- staged hunks (index vs HEAD)
  local cached = run(root, { 'diff', '--cached', '-U0' })
  if cached and cached ~= '' then
    for _, h in ipairs(parse_diff(cached, root)) do
      h.status = 'staged'
      hunks[#hunks + 1] = h
    end
  end

  -- unstaged hunks (worktree vs index)
  local stdout = run(root, { 'diff', '-U0' })
  if stdout and stdout ~= '' then
    for _, h in ipairs(parse_diff(stdout, root)) do
      h.status = 'unstaged'
      hunks[#hunks + 1] = h
    end
  end

  -- untracked files: one entry each, whole file = added lines
  local out = run(root, { 'ls-files', '--others', '--exclude-standard' })
  if out then
    for f in out:gmatch('(.-)\n') do
      if f ~= '' then
        local ok_read, lines = pcall(vim.fn.readfile, root .. '/' .. f)
        if ok_read and type(lines) == 'table' and #lines > 0 then
          local hlines = {}
          for _, l in ipairs(lines) do hlines[#hlines + 1] = { t = '+', s = l } end
          hunks[#hunks + 1] = {
            file = f, oldstart = 0, oldcount = 0,
            newstart = 1, newcount = #lines, lines = hlines,
            status = 'untracked',
          }
        end
      end
    end
  end
  return hunks
end

------------------------------------------------------------------------------- preview

-- Diff bg colors from config.lua diff_bg (muted green/red).
-- BG only: treesitter syntax fg stays readable.
local HL_ADD, HL_DEL = 'GithunksAdd', 'GithunksDel'
vim.api.nvim_set_hl(0, HL_ADD, { default = true, bg = '#1e3a2e' })
vim.api.nvim_set_hl(0, HL_DEL, { default = true, bg = '#3a252a' })

-- git status icon colors (GitHub git status palette)
vim.api.nvim_set_hl(0, 'GithunksStaged', { default = true, fg = '#3fb950' })
vim.api.nvim_set_hl(0, 'GithunksUnstaged', { default = true, fg = '#f85149' })
vim.api.nvim_set_hl(0, 'GithunksUntracked', { default = true, fg = '#d29922' })

-- Build full-file preview lines for one hunk: the complete new file content
-- (syntax-highlightable context) with the hunk's deleted lines inserted inline.
-- Returns display_lines, add_rows, del_rows (0-based buffer rows).
local function preview_rows(root, hunk)
  local path = root .. '/' .. hunk.file
  local ok_read, file_lines = pcall(vim.fn.readfile, path)
  if not ok_read or type(file_lines) ~= 'table' then file_lines = { '(cannot read file: ' .. path .. ')' } end

  local dels = {}
  for _, l in ipairs(hunk.lines) do
    if l.t == '-' then dels[#dels + 1] = l.s end
  end

  -- where deleted lines sit relative to the new file:
  --   replacement hunk: before the added lines (newstart .. newstart+n-1)
  --   pure deletion (newcount == 0): after the first `newstart` new-file lines
  local p = (hunk.newcount == 0) and hunk.newstart or (hunk.newstart - 1)
  -- clamp against file length (file may have changed since diff)
  p = math.max(0, math.min(p, #file_lines))

  local disp = {}
  for i = 1, #file_lines do disp[i] = file_lines[i] end
  for k = #dels, 1, -1 do table.insert(disp, p + 1, dels[k]) end

  local add_row0 = p + #dels
  local add_rows, del_rows = {}, {}
  for i = 0, hunk.newcount - 1 do add_rows[#add_rows + 1] = add_row0 + i end
  for i = 0, #dels - 1 do del_rows[#del_rows + 1] = p + i end
  return disp, add_rows, del_rows
end

------------------------------------------------------------------------------- picker

function M.pick(opts)
  opts = opts or {}

  local pickers = require('telescope.pickers')
  local make_entry = require('telescope.make_entry')

  local root, err = repo_root(vim.fn.getcwd())
  if not root then
    vim.notify('[githunks] not in a git repo: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end

  local entries = build_entries(root)
  if #entries == 0 then
    vim.notify('[githunks] no hunks vs HEAD under ' .. root, vim.log.levels.WARN)
  end
  local pick_entries = {}
  local seen = {}

  -- git status icons: FontAwesome core (f055/f056/f059) — present in every
  -- nerd font, unlike octicon codepoints which may be missing
  local ICONS = {
    staged = '\239\129\149',    -- U+F055 nf-fa-plus_circle
    unstaged = '\239\129\150',   -- U+F056 nf-fa-minus_circle
    untracked = '\239\129\153',  -- U+F059 nf-fa-question_circle
  }
  local devicons_ok, devicons = pcall(require, 'nvim-web-devicons')
  local function file_icon(f)
    if not devicons_ok then return '', '' end
    local icon, hl = devicons.get_icon(f, f:match('%.(%w+)$'), { default = true })
    return icon or '', hl or 'DevIconDefault'
  end

  -- line range shown in the display: new lines, or old lines for pure deletions
  local function range_of(e)
    if e.newcount > 1 then return e.newstart .. '-' .. (e.newstart + e.newcount - 1) end
    if e.newcount == 1 then return tostring(e.newstart) end
    if e.oldcount > 1 then return e.oldstart .. '-' .. (e.oldstart + e.oldcount - 1) end
    return tostring(e.oldstart)
  end

  -- width-less items never truncate; hl on 2nd item colors the icon.
  -- (lazy display fn, so entry_display width resolution runs after layout mount)
  local displayer = entry_display.create {
    separator = ' ',
    items = {
      {},                    -- status icon (own hl group)
      {},                    -- file icon (devicons hl group)
      { remaining = true },  -- path:range + first hunk line
    },
  }

  local make_display = function(entry)
    local fi, fhl = file_icon(entry.file)
    local status = entry.status or 'untracked'
    print('[display] ' .. entry.file .. '@' .. entry.newstart .. ' status=' .. tostring(entry.status))
    local shl = 'Githunks' .. status:sub(1, 1):upper() .. status:sub(2)
    return displayer {
      { ICONS[status] or '?', shl },
      { fi, fhl },
      entry.file .. ':' .. range_of(entry)
        .. '  ' .. (entry.lines[1] and entry.lines[1].s or ''),
    }
  end

  local finder = require('telescope.finders').new_table {
    results = entries,
    entry_maker = function(entry)
      -- collect our own stable list: entry_maker re-invoked on every finder
      -- re-process, but the same hunk tables are passed each time, so a
      -- seen-map keeps a complete authoritative snapshot that is safe to
      -- iterate even while the manager is mid-rebuild (manager:iter() can
      -- return empty during the async re-process after _on_lines)
      if not seen[entry] then
        seen[entry] = true
        pick_entries[#pick_entries + 1] = entry
      end
      entry.value = entry          -- value = the hunk table itself
      entry.ordinal = entry.file .. ' ' .. string.format('%012d', entry.newstart) .. ' ' .. (entry.lines[1] and entry.lines[1].s or '')
      entry.display = make_display -- lazy fn, rendered after picker mounts
      return make_entry.set_default_entry_mt(entry, opts)
    end,
  }

  local previewer = require('telescope.previewers').new_buffer_previewer({
    title = 'diff',
    define_preview = function(self, entry)
      -- self.state (with .bufnr) only exists here, after preview buffer mount.
      local hunk = entry.value
      local disp, add_rows, del_rows = preview_rows(root, hunk)
      local buf = self.state.bufnr
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, disp)
      -- name buffer after the real file so filetype/syntax detection kicks in
      pcall(vim.api.nvim_buf_set_name, buf, root .. '/' .. hunk.file)
      local ft = vim.filetype.match({ filename = hunk.file, buf = buf }) or ''
      pcall(vim.api.nvim_set_option_value, 'filetype', ft, { buf = buf })
      -- octo-style full-line diff backgrounds (syntax highlighting preserved)
      local ns = vim.api.nvim_create_namespace('githunks-preview')
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      for _, r in ipairs(add_rows) do
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, r, 0, { line_hl_group = HL_ADD })
      end
      for _, r in ipairs(del_rows) do
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, r, 0, { line_hl_group = HL_DEL })
      end
      -- scroll preview so the hunk is in view (a few lines of context above).
      -- MUST be scheduled: telescope connects the buffer to the preview window
      -- asynchronously (see buffer_previewer.lua), so an immediate
      -- win_set_cursor scrolls the previous buffer and is lost.
      local top_row = (del_rows[1] or add_rows[1])
      if top_row then
        vim.schedule(function()
          pcall(vim.api.nvim_win_set_cursor, self.state.winid, { math.max(1, top_row - 2), 0 })
        end)
      end
    end,
  })

  -- fresh staged/unstaged hunks from git, grouped per file (parse order is
  -- ascending hunk position). Called fresh on every retick.
  local function live_status(root)
    local staged, unstaged = {}, {}
    local function fill(map, text, tag)
      if not text or text == '' then return end
      for _, h in ipairs(parse_diff(text, root)) do
        h.status = tag
        local f = h.file
        if not map[f] then map[f] = {} end
        map[f][#map[f] + 1] = h
      end
    end
    fill(staged, run(root, { 'diff', '--cached', '-U0' }), 'staged')
    fill(unstaged, run(root, { 'diff', '-U0' }), 'unstaged')

    local untracked = {}
    local out = run(root, { 'ls-files', '--others', '--exclude-standard' })
    if out then
      for f in out:gmatch('(.-)\n') do if f ~= '' then untracked[f] = true end end
    end
    return staged, unstaged, untracked
  end

  -- Recompute staged/unstaged per hunk and flip status in place on the live
  -- entry tables, then re-tick the SAME finder (same entry objects, same
  -- ordinals → same order); 'follow' then keeps the cursor on the entry.
  --
  -- Matching is ORDER-based, not coordinate- or content-based. While the
  -- picker is open the only thing that moves is the index; worktree and HEAD
  -- line numbers are frozen, so each file's hunks keep their relative order
  -- no matter which pool (staged/unstaged) they land in. Pairing the i-th
  -- entry of a file with the i-th fresh hunk (position-sorted) survives
  -- coordinate shifts after staging, and can never confuse two hunks with
  -- identical content — the exact failure of the old coordinate/signature
  -- keying (two byte-identical "sudo *" hunks in one file).
  local function retick(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local staged, unstaged, untracked = live_status(root)

    local by_file, order = {}, {}
    for _, entry in ipairs(pick_entries) do
      local f = entry.value.file
      if not by_file[f] then by_file[f] = {}; order[#order + 1] = f end
      by_file[f][#by_file[f] + 1] = entry
    end

    for i = 1, #order do
      local fresh = {}
      -- NB: never ipairs over {a, b} with a possibly-nil a — ipairs stops at
      -- the first nil and silently drops everything after it
      for _, list in ipairs({ staged[order[i]] or {}, unstaged[order[i]] or {} }) do
        for _, h in ipairs(list) do fresh[#fresh + 1] = h end
      end
      table.sort(fresh, function(a, b) return a.newstart < b.newstart end)

      for j, entry in ipairs(by_file[order[i]]) do
        local h = fresh[j]
        if h then
          -- sync to the live hunk so coords/display refresh; status comes
          -- from which pool the hunk lives in
          print('[retick-set] ' .. order[i] .. ' j=' .. j .. ' oldstatus=' .. tostring(entry.status)
            .. ' -> ' .. tostring(h.status) .. ' value-newstart=' .. entry.value.newstart)
          entry.value = h
          entry.status = h.status
          print('[retick-after] ' .. order[i] .. ' j=' .. j .. ' status=' .. tostring(entry.status)
            .. ' value-status=' .. tostring(entry.value.status) .. ' value-newstart=' .. entry.value.newstart)
        elseif untracked[order[i]] then
          entry.status = 'untracked'
        else
          entry.status = nil
        end
      end
    end
    picker:_on_lines(nil, nil, nil, 0, 1)
  end

  -- build a minimal -U0 patch containing exactly this hunk
  local function hunk_patch(h)
    local parts = {
      'diff --git a/' .. h.file .. ' b/' .. h.file,
      '--- a/' .. h.file,
      '+++ b/' .. h.file,
      string.format('@@ -%d,%d +%d,%d @@', h.oldstart, h.oldcount, h.newstart, h.newcount),
    }
    for _, l in ipairs(h.lines) do parts[#parts + 1] = l.t .. l.s end
    return table.concat(parts, '\n') .. '\n'
  end

  local function git_apply(args, patch)
    local r = vim.system({ 'git', '-C', root, 'apply', '--cached', '--unidiff-zero', unpack(args) },
      { stdin = patch, text = true }):wait()
    if r.code ~= 0 then
      vim.notify('[githunks] apply failed: ' .. (r.stderr or 'unknown'), vim.log.levels.ERROR)
      return false
    end
    return true
  end

  local function stage_selected(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    if not entry then return end
    local h = entry.value
    if entry.status == 'untracked' then
      vim.system({ 'git', '-C', root, 'add', '--', root .. '/' .. h.file }, { text = true }):wait()
    elseif entry.status == 'staged' then
      return -- already staged
    else
      -- hunk comes from the unstaged diff (worktree vs index): its old side IS
      -- the index, so applying it with --cached stages exactly this hunk
      if not git_apply({}, hunk_patch(h)) then return end
    end
    vim.notify('staged: ' .. h.file .. ':' .. h.newstart, vim.log.levels.INFO)
    retick(prompt_bufnr)
  end

  local function unstage_selected(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    if not entry then return end
    local h = entry.value
    if entry.status ~= 'staged' then return end -- not staged (untracked or unstaged)
    if h.oldstart == 0 and h.oldcount == 0 then
      -- whole file is new in the index: unstage = remove it from the index
      vim.system({ 'git', '-C', root, 'rm', '--cached', '--quiet', '--', h.file }, { text = true }):wait()
    else
      -- hunk comes from the staged diff (index vs HEAD): reverse-applying it
      -- to the index removes exactly this hunk's changes
      if not git_apply({ '-R' }, hunk_patch(h)) then return end
    end
    vim.notify('unstaged: ' .. h.file .. ':' .. h.newstart, vim.log.levels.INFO)
    retick(prompt_bufnr)
  end

  local function select_and_close(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    if not entry then return end
    actions.close(prompt_bufnr)
    local path, lnum = root .. '/' .. entry.value.file, entry.value.newstart
    vim.schedule(function()
      local ok, existing = pcall(vim.api.nvim_find_buf_by_name, path)
      if ok and existing and vim.api.nvim_buf_is_loaded(existing) then
        vim.api.nvim_set_current_buf(existing)
      else
        vim.cmd('edit ' .. vim.fn.fnameescape(path))
      end
      vim.api.nvim_win_set_cursor(0, { lnum, 1 })
    end)
  end

  pickers.new(opts, {
    prompt_title = 'Git hunks',
    finder = finder,
    sorter = conf.file_sorter(opts),
    previewer = previewer,
    preview_title = 'diff',
    -- fill results bottom-to-top (newest entry at the bottom, telescope default)
    sorting_strategy = 'descending',
    -- keep selection on the same entry when results re-tick (stage/unstage)
    selection_strategy = 'follow',
    layout_config = { horizontal = { preview_width = 0.6 } },
    attach_mappings = function(_, map)
      map({ 'i', 'n' }, '<CR>', select_and_close)
      map({ 'i' }, '<C-s>', stage_selected)
      map({ 'i' }, '<C-u>', unstage_selected)
      map({ 'n' }, 's', stage_selected)
      map({ 'n' }, 'u', unstage_selected)
      return true
    end,
  }):find()
end

return M
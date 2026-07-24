local M = {}

local downloads = (os.getenv('HOME') or '') .. '/Downloads'

function M:setup()
  ps.sub('ind-sort', function(opt)
    local cwd = tostring(cx.active.current.cwd)
    if cwd == downloads then
      opt.by, opt.reverse, opt.dir_first = 'mtime', true, false
    else
      opt.by, opt.reverse, opt.dir_first = 'alphabetical', false, true
    end
    return opt
  end)
end

return M

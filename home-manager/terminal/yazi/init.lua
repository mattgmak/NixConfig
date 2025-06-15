-- require("starship"):setup()
require("relative-motions"):setup({
    show_numbers = "relative",
    show_motion = true
})
-- require("searchjump"):setup{
--     opt_unmatch_fg = "#928374",
--     opt_match_str_fg = "#000000",
--     opt_match_str_bg = "#73AC3A",
--     opt_lable_fg = "#EADFC8",
--     opt_lable_bg = "#BA603D"
-- }
-- require("yaziline"):setup({
--     separator_style = "curvy", -- "angly" | "curvy" | "liney" | "empty"
--     -- separator_open = "",
--     -- separator_close = "",
--     -- separator_open_thin = "",
--     -- separator_close_thin = "",
--     select_symbol = "",
--     yank_symbol = "󰆐",
--     filename_max_length = 24, -- trim when filename > 24
--     filename_trim_length = 6 -- trim 6 chars from both ends
-- })
-- Add symlink to status bar
Status:children_add(function(self)
    local h = self._current.hovered
    if h and h.link_to then
        return " -> " .. tostring(h.link_to)
    else
        return ""
    end
end, 3300, Status.LEFT)

-- Add user and group to status bar
Status:children_add(function()
    local h = cx.active.current.hovered
    if h == nil or ya.target_family() ~= "unix" then
        return ""
    end

    return ui.Line {ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg("magenta"), ":",
                    ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg("magenta"), " "}
end, 500, Status.RIGHT)

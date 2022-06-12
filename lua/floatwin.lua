-- vim:foldmethod=marker:foldlevel=0

-- highlight {{{1

vim.api.nvim_create_augroup('floatwin_highlight', {clear = false})

local function highlight(hi)
    local command = 'highlight ' .. table.concat(hi, ' ')
    vim.api.nvim_create_autocmd('ColorScheme', {pattern = '*', command = command})
end

local g = vim.g

local FloatWinBorder_ctermfg = g.floatwin_border_ctermfg or 75
local FloatWinBorder_guifg = g.floatwin_border_guifg or '#82b1ff'

vim.validate {
    floatwin_border_ctermfg={FloatWinBorder_ctermfg, {'number', 'string'}},
    floatwin_border_guifg={FloatWinBorder_guifg, 'string'},
}

highlight {
    'FloatWinBorder',
    'ctermfg='..tostring(FloatWinBorder_ctermfg),
    'guifg='..FloatWinBorder_guifg,
    'guibg=background'
}

highlight {
    'FloatWinText',
    'guibg=background'
}

-- 1}}}

-- borders {{{1

local border_effects = {
    'solid', 'shadow'
}

local rounded_border = {'╭', '─', '╮', '│', '╯', '─', '╰', '│'}

--[[
local border_no_title = {
    {'╭', 'FloatWinBorder'},
    {'─', 'FloatWinBorder'},
    {'╮', 'FloatWinBorder'},
    {'│', 'FloatWinBorder'},
    {'╯', 'FloatWinBorder'},
    {'─', 'FloatWinBorder'},
    {'╰', 'FloatWinBorder'},
    {'│', 'FloatWinBorder'}
}
--]]
-- 1}}}

-- local:validate_options {{{1

-- Validate options passed from users
local function validate_options(valid, opts)
    if not opts then return end

    -- local function optional_tostring {{{2
    local function optional_tostring(arg)
        if type(arg) == 'string' then return arg end

        return table.concat(arg, '|')
    end
    -- 2}}}

    -- local function type_is_valid {{{2
    local function type_is_valid(valid_types, val)
        local typeof_val = type(val)
        if type(valid_types) == 'string' and typeof_val == valid_types then
            return true
        end

        for _,valid_type in ipairs(valid_types) do
            if typeof_val == valid_type then
                return true
            end
        end
        return false
    end
    -- 2}}}

    for optname,val in pairs(opts) do
        -- check if we know the option
        if valid[optname] == nil then
            error('unknown option: '..tostring(key), 3)
        end

        if not type_is_valid(valid[optname], val) then
            local valid_str = optional_tostring(valid[key])
            error('invalid option '..key..': expected '..valid_str..', got '..type(val), 3)
        end

        if valid[optname].required and not opts[valid[optname].required] then
            error('option '..optname..': required option '..valid[optname].required, 3)
        end
    end
end

-- 1}}}

local M = {}
vim.api.nvim_create_augroup('floatwin_windows', {clear = false})

local opened_windows = {}

local default_opts = {
    relative = 'editor',
    anchor = 'NW',
    focusable = false,
    style = 'minimal',
    --border = 'shadow',
    noautocmd = true
}

local _repeat = vim.fn['repeat']
local flatten = vim.fn['flatten']
local map = vim.fn['map']
local range = vim.fn['range']

local function construct_border(width, height, border, title)
    local title_len = string.len(title)
    if title_len > (width - 2) then
        local needed_width = tostring(title_len + 2)
        error('title too big for window: at least '..needed_width..' width is required', 3)
    end

    local repeat_num = (width-2) - title_len
    local h_border_top = border[1] .. title .. _repeat(border[2], repeat_num) ..border[3]
    local empty_line = '"'.. border[8] .. _repeat(' ', width-2) ..border[4] .. '"'
    local h_border_bottom = border[7] .. _repeat(border[2], width-2) ..border[5]
    return flatten({h_border_top, map(range(height-2), empty_line), h_border_bottom})
end

local function close_last_window()
    if not vim.b.floatwin_last_opened_win then return end
    pcall(M.close, vim.b.floatwin_last_opened_win)
    vim.b.floatwin_last_opened_win = nil
end

local set_keymap = vim.api.nvim_set_keymap
set_keymap('n', '', '', {callback = close_last_window})

-- config options
--     enter: true, false                       - default: false
--  relative: "editor", <winid>, "cursor"       - default: "editor"
--    anchor: "NW", "NE", "SW", "SE"            - default: "NW"
--     width: <width>                           - default: adjusted to text
--    height: <height>                          - default: adjusted to text
--       row: <row>                             - default: centered
--       col: <col>                             - default: centered
--     title: <string>                          - default: <none>
-- border_highlight: highlight_group            - default: FloatWinBorder
-- text_highlight: highlight_group              - default: FloatWinText
function M.float(text, user_opts)
    vim.validate {
        text = {text, 'table'},
        opts = {user_opts, {'nil','table'}}
    }

    validate_options({
        relative = {'string', 'number'},
        anchor = 'string',
        width = 'number',
        height = 'number',
        -- below are options that will not be passed to nvim_open_win()
        -- directly but needs further processing
        row = {'number', required = 'col'},
        col = {'number', required = 'row'},
        title = 'string',
        border_highlight = 'string',
        text_highlight = 'string'
    }, user_opts)

    local opts = {}
    -- we need to copy only the options that is going to
    -- be passed to nvim_open_win()
    for key,val in pairs(default_opts) do
        if user_opts and user_opts[key] then
            opts[key] = user_opts[key]
        else
            opts[key] = val
        end
    end

    local enter = user_opts and user_opts.enter or false

    -- support using a number directly instead of the caller
    -- supplying relative='win' + win=<number>
    if type(opts.relative) == 'number' then
        opts.relative = 'win'
        opts.win = opts.relative
    end

    local win_width, win_height
    if opts.relative == 'editor' then
        local ui = vim.api.nvim_list_uis()[1]
        win_width = ui.width
        -- decrement the size of the statuline + command-line
        -- so that the window will be centered in the text area
        win_height = ui.height - 3
    else
        win_width = vim.api.nvim_win_get_width(0) - vim.wo.numberwidth
        win_height = vim.api.nvim_win_get_height(0)
    end

    local longest_line = 0
    for _, s in ipairs(text) do
        local len = string.len(s)
        longest_line = (len > longest_line) and len or longest_line
    end

    opts.width = longest_line + 2 -- increment the border size
    opts.height = #text + 2 -- increment the border size

    if opts.width > win_width or opts.height > win_height then
        error('floating window too big for current window')
    end

    local title = ''

    if user_opts and user_opts.title then
        title = ' ' .. user_opts.title .. ' '
    end

    local border = construct_border(opts.width, opts.height, rounded_border, title)

    if not user_opts or user_opts.row == nil then
        opts.row = (win_height / 2) - (opts.height /2)
        opts.col = (win_width / 2) - (opts.width /2)
    else
        opts.row = user_opts.row
        opts.col = user_opts.col
    end

    local border_highlight = user_opts and user_opts.border_highlight or 'FloatWinBorder'
    local text_highlight = user_opts and user_opts.text_highlight or 'FloatWinText'

    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(buf, 0, 0, false, border)
    -- delete the line added at the end so that the use won't scroll past the border
    vim.api.nvim_buf_set_lines(buf, -2, -1, false, {})

    vim.api.nvim_buf_add_highlight(buf, -1, border_highlight, 0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, border_highlight, opts.height-1, 0, -1)

    for linenr, line in ipairs(text) do
        vim.api.nvim_buf_add_highlight(buf, -1, border_highlight, linenr, 0, 3)
        vim.api.nvim_buf_add_highlight(buf, -1, border_highlight, linenr, opts.width-3, -1)

        local line_len = string.len(line)
        -- we need to offset by 3 because nvim_buf_set_text() uses
        -- byte offsets, and the border characters uses 3 bytes in
        -- utf-8
        vim.api.nvim_buf_set_text(buf, linenr, 3, linenr, line_len+3, {line})
        vim.api.nvim_buf_add_highlight(buf, -1, text_highlight, linenr, 3, opts.width+3)
    end

    local handle = vim.api.nvim_open_win(buf, enter, opts)

    vim.api.nvim_win_set_option(handle, 'linebreak', false)

    -- nvim_win_set_config() does not accept 'noautocmd' so we remove it here
    opts.noautocmd = nil
    vim.b.floatwin_last_opened_win = handle

    local thisbuffer = vim.api.nvim_get_current_buf()
    if not opened_windows[thisbuffer] then
        table.insert(opened_windows, thisbuffer, {})
    end

    opened_windows[thisbuffer][handle] = {
        handle = handle,
        opts = opts,
        buf = buf
    }

    return opened_windows[thisbuffer][handle]
end

--[[
--  options:
--
-- border_highlight: highlight_group            - default: FloatWinBorder
-- text_highlight: highlight_group              - default: FloatWinText
--]]
function M.tooltip(text, user_opts)
    vim.validate {
        text = {text, 'table'},
        opts = {user_opts, {'nil', 'table'}},
    }

    validate_options({
        border_highlight = 'string',
        text_highlight = 'string',
    }, user_opts)

    -- local function get_rel_pos {{{1
    local function get_rel_pos(width, height)
        local win_width = vim.api.nvim_win_get_width(0) - vim.wo.numberwidth

        local cursor_row, cursor_col = table.unpack(vim.api.nvim_win_get_cursor(0))

        local anchor_v = 'S'
        local anchor_h = 'W'
        local row = 0
        local col = 0
        if width > (win_width - cursor_col) then
            anchor_h = 'E'
            col = 1
        end

        if height >= cursor_row then
            anchor_v = 'N'
            row = 1
        end

        return anchor_v..anchor_h, row, col
    end
    -- 1}}}

    local opts = {
        relative = 'cursor'
    }

    if user_opts then
        opts.border_highlight = user_opts.border_highlight
        opts.text_highlight = user_opts.text_highlight
    end

    local longest_line = 0
    for _, s in ipairs(text) do
        local len = string.len(s)
        longest_line = (len > longest_line) and len or longest_line
    end

    local width = longest_line + 2
    local height = #text + 2

    opts.anchor, opts.row, opts.col = get_rel_pos(width, height, opts.border)

    local res = M.float(text, opts)
    local thisbuffer = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_option(res.buf, 'modifiable', false)

    -- local function follow_cursor {{{1
    local function follow_cursor(arg)
        local buf = arg.buf
        if opened_windows[buf] then
            local opts = opened_windows[buf].opts
            opts.anchor, opts.row, opts.col = get_rel_pos(opts.width, opts.height, opts.border)
            vim.api.nvim_win_set_config(opened_windows[buf].handle, opts)
        end
    end
    -- 1}}}

    vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
        group = groupid,
        buffer = thisbuffer,
        callback = follow_cursor
    })

    return res.handle
end

function M.close(winhandle)

    local buf = vim.api.nvim_get_current_buf()

    if opened_windows[buf] and opened_windows[buf][winhandle] then
        vim.api.nvim_win_hide(winhandle)
        opened_windows[buf][winhandle] = nil
        return
    end

    error('invalid window handle', 2)
end

return M

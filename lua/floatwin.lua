vim.api.nvim_create_augroup('floatwin_windows', {clear = false})

local M = {}

local default_opts = {
    relative = 'editor',
    anchor = 'NW',
    border = 'rounded',
    focusable = false,
    style = 'minimal',
    noautocmd = true
}

local opened_windows = {}

local function get_real_size(width, height, _border)
    local border = _border or default_opts.border

    local full_width = width
    local full_height = height

    if border ~= 'none' then
        full_width = full_width + 2
        full_height = full_height + 2
    end

    return full_width, full_height
end

local function validate_options(valid, opts)
    if not opts then return end

    local function optional_tostring(arg)
        if type(arg) == 'string' then return arg end

        return table.concat(arg, '|')
    end

    local function check_type(optname, opt)
        local typeof_opt = type(opt)
        local valid_type = valid[optname]
        if type(valid_type) == 'string' then
            if typeof_opt == valid_type then return true end
        else
            for _,tp in ipairs(valid_type) do
                if typeof_opt == tp then return true end
            end
        end

        return false
    end

    for key,val in pairs(opts) do
        if valid[key] == nil then
            error('unknown option: '..tostring(key), 3)
        end

        if not check_type(key, val) then
            local valid_str = optional_tostring(valid[key])
            error('invalid option '..key..': expected '..valid_str..', got '..type(val), 3)
        end
    end
end

-- config options
--     enter: true, false                       - default: false
--  relative: "editor", <winid>, "cursor"       - default: "editor"
--    anchor: "NW", "NE", "SW", "SE"            - default: "NW"
--       row: <row>                             - default: centered
--       col: <col>                             - default: centered
--    border: "none", "single", "double",
--            "rounded", "solid", "shadow"      - default: "rounded"
-- focusable: true, false                       - default: false
--     style: "minimal", "none"                 - default: "minimal"
-- noautocmd: true, false                       - default: true
function M.float(width, height, text, user_opts)
    vim.validate {
        width = {width, 'number'},
        height = {height, 'number'},
        text = {text, {'nil', 'string', 'table'}},
        user_opts = {user_opts, {'nil','table'}}
    }

    validate_options({
        enter = 'boolean',
        relative = {'string', 'number'},
        anchor = 'string',
        row = 'number',
        col = 'number',
        border = 'string',
        focusable = 'boolean',
        style = 'string',
        noautocmd = 'boolean',
        win = 'number'
    }, user_opts)
    local opts = {}

    for key,val in pairs(default_opts) do
        if user_opts and user_opts[key] then
            opts[key] = user_opts[key]
        else
            opts[key] = val
        end
    end

    if opts.style ~= 'minimal' then
        table.remove(opts, 'minimal')
    end

    local use_ui = true
    if type(opts.relative) == 'string' and opts.relative ~= 'editor' then
        use_ui = false
    elseif type(opts.relative) == 'number' then
        opts.relative = 'win'
        opts.win = opts.relative
    end

    local win_width
    local win_height

    if use_ui then
        local ui = vim.api.nvim_list_uis()[1]
        win_width = ui.width
        win_height = ui.height - 3
    else
        win_width = vim.api.nvim_win_get_width(0) - vim.wo.numberwidth
        win_height = vim.api.nvim_win_get_height(0)
    end

    local full_width, full_height = get_real_size(width, height, opts.border)

    if full_width > win_width or full_height > win_height then
        error('floating window too big for current window')
    end

    opts.width = width
    opts.height = height

    if opts.row == nil then
        opts.row = (win_height / 2) - (height /2)
    end

    if opts.col == nil then
        opts.col = (win_width / 2) - (width /2)
    end

    print(opts.row .. ':'..opts.col)

    local enter = user_opts and user_opts.enter or false
    local buf = vim.api.nvim_create_buf(false, true)

    if type(text) == 'table' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
    elseif type(text) == 'string' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {text})
    end

    -- nvim_win_set_config() does not accept noautocmd
    opts.noautocmd = nil
    return {handle = vim.api.nvim_open_win(buf, enter, opts), opts = opts}
end

-- [[
--   follows_cursor: true, false                - default: true
--    border: "none",    "single", "double",
--            "rounded", "solid",  "shadow"     - default: "rounded"
-- ]]
function M.tooltip(width, height, text, user_opts)
    vim.validate {
        width = {width, 'number'},
        height = {height, 'number'},
        text = {text, {'string', 'table'}},
        user_opts = {user_opts, {'table','nil'}}
    }

    validate_options({
            follows_cursor = 'boolean',
            border = 'string'
    }, user_opts)

    local function get_rel_pos(width, height, border)
        local win_width = vim.api.nvim_win_get_width(0) - vim.wo.numberwidth

        local full_width, full_height = get_real_size(width, height, border)
        local cursor_row, cursor_col = table.unpack(vim.api.nvim_win_get_cursor(0))

        local anchor_v = 'S'
        local anchor_h = 'W'
        local row = 0
        local col = 0
        if full_width > (win_width - cursor_col) then
            anchor_h = 'E'
            col = 1
        end

        if full_height >= cursor_row then
            anchor_v = 'N'
            row = 1
        end

        return anchor_v..anchor_h, row, col
    end

    local opts = {}
    if user_opts and user_opts.border then opts.border = user_opts.border end
    opts.relative = 'cursor'

    opts.anchor, opts.row, opts.col = get_rel_pos(width, height, opts.border)

    local res = M.float(width, height, text, opts)
    local thisbuffer = vim.api.nvim_get_current_buf()

    table.insert(opened_windows, thisbuffer, res)

    local function follow_cursor(arg)
        local buf = arg.buf
        if opened_windows[buf] then
            local opts = opened_windows[buf].opts
            opts.anchor, opts.row, opts.col = get_rel_pos(opts.width, opts.height, opts.border)
            vim.api.nvim_win_set_config(opened_windows[buf].handle, opts)
        end
    end

    if not user_opts or user_opts.follows_cursor then
        vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
            group = groupid,
            buffer = thisbuffer,
            callback = follow_cursor
        })
    end

    return res.handle
end

function M.close(winhandle)
    if opened_windows[buf] then
        vim.api.nvim_hide(opened_windows[buf].handle)
        table.remove(opened_windows, buf)
        return
    end

    error('invalid window handle', 2)
end

return M

augroup floatwin
    au!
augroup END

let s:curr_float_windows={}

function! FloatWinCloseWin(win_handle)
    if (type(a:win_handle) != v:t_number)
        throw "(FloatWin::error) argument win must be of number type"
    endif

    if (!has_key(s:curr_float_windows, a:win_handle))
        throw "(FloatWin::error) unknown window"
    endif

    autocmd! floatwin CursorMoved,CursorMovedI <buffer>

    call remove(s:curr_float_windows, a:win_handle)
    call nvim_win_hide(a:win_handle)
endfunction

function! FloatWinUpdatePosition(win_handle)
    if (type(a:win_handle) != v:t_number)
        throw "(FloatWin::error) argument win must be of number type"
    endif

    if (!has_key(s:curr_float_windows, a:win_handle))
        throw "(FloatWin::error) unknown window"
    endif

    let win_opts = s:curr_float_windows[a:win_handle]
    call nvim_win_set_config(a:win_handle, win_opts)
endfunction

" create a window located relative to the cursor, like a tooltip.
"
"          style: "minimal", "none"
"      focusable: true, false
" follows_cursor: true, false
function! FloatWinCreateWinCursorRel(winsize, style="none", focusable=v:true, follows_cursor=v:true)
    if (type(a:winsize) != v:t_list || len(a:winsize) != 2)
        throw "(FloatWin::error) winsize must be a list of size 2 => [width, height]"
    endif

    let win_width = a:winsize[0]
    let win_height = a:winsize[1]

    let curr_window_height = nvim_win_get_height(0)
    let curr_window_width = nvim_win_get_width(0)

    if (win_width > curr_window_width || win_height > curr_window_height)
        throw "(FloatWin::error) floating window too big for current window"
    endif

    let cursor_pos = getpos(".")

    let win_height_with_border = win_height + 2
    if (win_height_with_border > cursor_pos[1])
        let anchor_vertical="N"
        let row=1
    endif

    let win_width_with_border = win_width + 2
    if (win_width_with_border > (curr_window_width - cursor_pos[2]))
        let anchor_horizontal="E"
        let col=1
    endif

    let opts = {
                \
        \ "anchor": get(l:, "anchor_vertical", "S").get(l:, "anchor_horizontal", "W"),
        \ "row": get(l:, "row", 0),
        \ "col": get(l:, "col", 0),
        \ "focusable": a:focusable,
        \ "style": a:style
      \ }

    let win_handle = floatwin#create_float_win(a:focusable, win_width, win_height, opts)

    call extend(s:curr_float_windows, {win_handle.handle: win_handle.opts})

    if (a:follows_cursor)
        let b:floatwin_window = win_handle.handle
        autocmd floatwin CursorMoved,CursorMovedI <buffer> call FloatWinUpdatePosition(b:floatwin_window)
    endif
    return win_handle.handle
endfunction

function! FloatWinCreateWinUIRel(winsize, pos="center", style="minimal", focusable=v:false)
    let win_width = a:winsize[0]
    let win_height = a:winsize[1]

    let win_width_with_border = win_width + 2
    let win_height_with_border = win_height + 2

    let ui = nvim_list_uis()[0]

    if (win_width > ui.width || win_height > ui.height)
        throw "(FloatWin::error) floating window too big for current neovim UI size"
    endif

    let col_spacing = 2
    let row_spacing = 1

    let statusline_rows = 3

    if (a:pos == "center")

        let col = (ui.width/2) - (win_width/2)
        let row = (ui.height/2) - (win_height/2)
    elseif (a:pos == "NW")
        let col = col_spacing
        let row = row_spacing
    elseif (a:pos == "NE")
        let col = &columns - col_spacing - win_width_with_border
        let row = row_spacing
    elseif (a:pos == "SW")
        let col = col_spacing
        let row = &lines - row_spacing - win_height_with_border - statusline_rows
    elseif (a:pos == "SE")
        let col = &columns - col_spacing - win_width_with_border
        let row = &lines - row_spacing - win_height_with_border - statusline_rows
    else
        throw "(FloatWin::error) floating window too big for current window"
    endif

    let opts = {
                \
        \ "row": row,
        \ "col": col,
        \ "relative": "editor",
        \ "focusable": a:focusable,
        \ "style": a:style
      \ }

    let win_handle = floatwin#create_float_win(a:focusable, win_width, win_height, opts)
    call extend(s:curr_float_windows, {win_handle.handle: win_handle.opts})

    return win_handle.handle
endfunction

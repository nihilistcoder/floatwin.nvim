" vim:foldmethod=marker:foldlevel=0

" config options
"  relative: "editor", <winid>, "cursor"        - default: "cursor"
"    anchor: "NW", "NE", "SW", "SE"             - default: "NW"
"       row: <row>                              - default: 1
"       col: <col>                              - default: 0
"    border: "none", "single", "double",
"            "rounded", "solid", "shadow"       - default: "rounded"
" focusable: v:true, v:false                    - default: v:true
"     style: "minimal", none                    - default: none
" noautocmd: v:true, v:false                    - default: v:false
function floatwin#create_float_win(grab, width, height, config) abort
    let scratch_buf = nvim_create_buf(v:false, v:true)

    let relative = get(a:config, "relative", "cursor")
    if (type(relative) == v:t_number)
        let opt_win = relative
        let relative = "win"
    endif

    let opts = {
            \ "relative": relative,
            \ "width": a:width,
            \ "height": a:height,
            \ "anchor": get(a:config, "anchor", "NW"),
            \ "row": get(a:config, "row", 1),
            \ "col": get(a:config, "col", 0),
            \ "border": get(a:config, "border", "rounded"),
            \ "focusable": get(a:config, "focusable", v:true),
            \ "noautocmd": get(a:config, "noautocmd", v:true)
          \ }

    if (get(a:config, "style", "") == "minimal")
        call extend(opts, {"style":"minimal"})
    endif

    if (relative == "win")
        call extend(opts, {"win":opt_win})
    endif

    " remove noautocmd since nvim_win_set_config() does not accept it
    call remove(opts, "noautocmd")

    return {"handle": nvim_open_win(scratch_buf, a:grab, opts), "opts": opts}
endfunction

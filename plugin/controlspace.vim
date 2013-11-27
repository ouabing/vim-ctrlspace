" Vim-ControlSpace - The Vim Way Space Controller
" Maintainer:   Szymon Wrozynski
" Version:      3.1.9
"
" Installation:
" Place in ~/.vim/plugin/controlspace.vim or in case of Pathogen:
"
"     cd ~/.vim/bundle
"     git clone https://github.com/szw/vim-controlspace.git
"
" License:
" Copyright (c) 2013 Szymon Wrozynski <szymon@wrozynski.com>
" Distributed under the same terms as Vim itself.
" Original BufferList plugin code - copyright (c) 2005 Robert Lillack <rob@lillack.de>
" Redistribution in any form with or without modification permitted.
" Licensed under MIT License conditions.
"
" Usage:
" https://github.com/szw/vim-controlspace/blob/master/README.md

if exists('g:controlspace_loaded')
  finish
endif

let g:controlspace_loaded = 1

function! <SID>define_config_variable(name, default_value)
  if !exists("g:controlspace_" . a:name)
    let g:{"controlspace_" . a:name} = a:default_value
  endif
endfunction

function! <SID>define_symbols()
  if g:controlspace_unicode_font
    let symbols = {
          \ "cs"      : "␣",
          \ "tab"     : "⊙",
          \ "all"     : "∷",
          \ "add"     : "○",
          \ "load"    : "▬ → ▭",
          \ "save"    : "▭ → ▬",
          \ "ord"     : "₁²₃",
          \ "abc"     : "авс",
          \ "prv"     : "⌕",
          \ "s_left"  : "›",
          \ "s_right" : "‹"
          \ }
  else
    let symbols = {
          \ "cs"      : "CS",
          \ "tab"     : "TAB",
          \ "all"     : "ALL",
          \ "add"     : "ADD",
          \ "load"    : "LOAD",
          \ "save"    : "SAVE",
          \ "ord"     : "123",
          \ "abc"     : "ABC",
          \ "prv"     : "*",
          \ "s_left"  : "[",
          \ "s_right" : "]"
          \ }
  endif

  return symbols
endfunction

call <SID>define_config_variable("height", 1)
call <SID>define_config_variable("max_height", 0)
call <SID>define_config_variable("show_unnamed", 2)
call <SID>define_config_variable("set_default_mapping", 1)
call <SID>define_config_variable("default_mapping_key", "<C-Space>")
call <SID>define_config_variable("cyclic_list", 1)
call <SID>define_config_variable("max_jumps", 100)
call <SID>define_config_variable("max_searches", 100)
call <SID>define_config_variable("default_sort_order", 2) " 0 - no sort, 1 - chronological, 2 - alphanumeric
call <SID>define_config_variable("use_ruby_bindings", 1)
call <SID>define_config_variable("use_tabline", 1)
call <SID>define_config_variable("session_file", [".git/cs_sessions", ".svn/cs_sessions", "CVS/cs_sessions", ".cs_sessions"])
call <SID>define_config_variable("cache_dir", expand($HOME))
call <SID>define_config_variable("project_root_markers", [".git", ".hg", ".svn", ".bzr", "_darcs"]) " make empty to disable
call <SID>define_config_variable("unicode_font", 1)
call <SID>define_config_variable("symbols", <SID>define_symbols())
call <SID>define_config_variable("ignored_files", '\v(tmp|temp)[\/]') " in addition to 'wildignore' option
call <SID>define_config_variable("show_key_info", 0)

command! -nargs=0 -range ControlSpace :call <SID>controlspace_toggle(0)
command! -nargs=0 -range ControlSpaceTabLabel :call <SID>new_tab_label()

if g:controlspace_use_tabline
  set tabline=%!controlspace#tabline()
endif

function! <SID>set_default_mapping(key, action)
  let s:default_key = a:key
  if !empty(s:default_key)
    if s:default_key ==? "<C-Space>" && !has("gui_running")
      let s:default_key = "<Nul>"
    endif

    silent! exe 'nnoremap <unique><silent>' . s:default_key . ' ' . a:action
  endif
endfunction

if g:controlspace_set_default_mapping
  call <SID>set_default_mapping(g:controlspace_default_mapping_key, ":ControlSpace<CR>")
endif

let s:files                 = []
let s:preview_mode          = 0
let s:active_session_name   = ""
let s:active_session_digest = ""
let s:session_names         = []

function! <SID>init_project_roots()
  let cache_file = g:controlspace_cache_dir . "/.cs_cache"
  let s:project_roots = []

  if filereadable(cache_file)
    for line in readfile(cache_file)
      if line =~# "CS_PROJECT_ROOT: "
        call add(s:project_roots, line[17:])
      endif
    endfor
  endif
endfunction

call <SID>init_project_roots()

function! <SID>add_project_root(directory)
  call add(s:project_roots, a:directory)

  let lines      = []
  let cache_file = g:controlspace_cache_dir . "/.cs_cache"

  if filereadable(cache_file)
    for old_line in readfile(cache_file)
      if old_line !~# "CS_PROJECT_ROOT: "
        call add(lines, old_line)
      endif
    endfor
  endif

  for root in s:project_roots
    call add(lines, "CS_PROJECT_ROOT: " . root)
  endfor


  call writefile(lines, cache_file)
endfunction

function! <SID>init_key_names()
  let lowercase_letters = "q w e r t y u i o p a s d f g h j k l z x c v b n m"
  let uppercase_letters = toupper(lowercase_letters)

  let control_letters_list = []

  for l in split(lowercase_letters, " ")
    call add(control_letters_list, "C-" . l)
  endfor

  let control_letters = join(control_letters_list, " ")

  let numbers       = "1 2 3 4 5 6 7 8 9 0"
  let special_chars = "Space CR BS Tab S-Tab / ? ; : , . < > [ ] { } ( ) ' ` ~ + - _ = ! @ # $ % ^ & * " .
                    \ "MouseDown MouseUp LeftDrag LeftRelease 2-LeftMouse Down Up Home End Left Right BSlash Bar"

  let special_chars .= has("gui_running") ? " C-Space" : " Nul"

  let s:key_names = split(join([lowercase_letters, uppercase_letters, control_letters, numbers, special_chars], " "), " ")

  if exists("s:default_key")
    for i in range(0, len(s:key_names) - 1)
      if ("<" . s:key_names[i] . ">") ==# s:default_key
        call remove(s:key_names, i)
        break
      endif
    endfor
  endif
endfunction

call <SID>init_key_names()

au BufEnter * call <SID>add_tab_buffer()

let s:controlspace_jumps = []
au BufEnter * call <SID>add_jump()

function! controlspace#bufferlist(tabnr)
  let buffer_list     = {}
  let controlspace    = gettabvar(a:tabnr, "controlspace_list")
  let visible_buffers = tabpagebuflist(a:tabnr)

  if type(controlspace) != 4
    return buffer_list
  endif

  for i in keys(controlspace)
    let i = str2nr(i)

    let bufname = bufname(i)

    if g:controlspace_show_unnamed && !strlen(bufname)
      if !((g:controlspace_show_unnamed == 2) && !getbufvar(i, '&modified')) || (index(visible_buffers, i) != -1)
        let bufname = '[' . i . '*No Name]'
      endif
    endif

    if strlen(bufname) && getbufvar(i, '&modifiable') && getbufvar(i, '&buflisted')
      let buffer_list[i] = bufname
    endif
  endfor

  return buffer_list
endfunction

function! controlspace#statusline_key_info_segment(...)
  let separator = (a:0 > 0) ? a:1 : " "
  let keys      = ["?"]

  if s:nop_mode
    if !s:search_mode
      if !empty(s:search_letters)
        call add(keys, "BS")
      endif

      call add(keys, "q")
      call add(keys, "a")
      call add(keys, "A")
      call add(keys, "^p")
      call add(keys, "^n")
    else
      call add(keys, "BS")
    endif

    return join(keys, separator)
  endif

  if s:search_mode
    call add(keys, "BS")
    call add(keys, "CR")
    call add(keys, "/")
    if s:file_mode
      call add(keys, '\')
    endif
    call add(keys, "a..z")
    call add(keys, "0..9")
  elseif s:file_mode
    call add(keys, "CR")
    call add(keys, "Sp")
    call add(keys, "BS")
    call add(keys, "/")
    call add(keys, '\')
    call add(keys, "v")
    call add(keys, "s")
    call add(keys, "t")
    call add(keys, "T")
    call add(keys, "0..9")
    call add(keys, "-")
    call add(keys, "+")
    call add(keys, "=")
    call add(keys, "_")
    call add(keys, "[")
    call add(keys, "]")
    call add(keys, "q")
    call add(keys, "j")
    call add(keys, "J")
    call add(keys, "k")
    call add(keys, "K")
    call add(keys, "C")
    call add(keys, "e")
    call add(keys, "E")
    call add(keys, "r")
    call add(keys, "R")
    call add(keys, "m")
    call add(keys, "a")
    call add(keys, "A")
    call add(keys, "^p")
    call add(keys, "^n")
    call add(keys, "l")
  elseif s:session_mode
    call add(keys, "CR")
    call add(keys, "BS")
    call add(keys, "q")

    if s:session_mode == 1
      call add(keys, "a")
    endif

    call add(keys, "s")
    call add(keys, "S")
    call add(keys, "d")
    call add(keys, "j")
    call add(keys, "J")
    call add(keys, "k")
    call add(keys, "K")
    call add(keys, "l")
  else
    call add(keys, "CR")
    call add(keys, "Sp")
    call add(keys, "Tab")
    call add(keys, "BS")
    call add(keys, "/")
    call add(keys, '\')
    call add(keys, "v")
    call add(keys, "s")
    call add(keys, "t")
    call add(keys, "T")
    call add(keys, "0..9")
    call add(keys, "-")
    call add(keys, "+")
    call add(keys, "=")
    call add(keys, "_")
    call add(keys, "[")
    call add(keys, "]")
    call add(keys, "o")
    call add(keys, "q")
    call add(keys, "j")
    call add(keys, "J")
    call add(keys, "k")
    call add(keys, "K")
    call add(keys, "p")
    call add(keys, "P")
    call add(keys, "n")
    call add(keys, "d")
    call add(keys, "D")
    if s:single_tab_mode
      call add(keys, "f")
    endif
    call add(keys, "F")
    if s:single_tab_mode
      call add(keys, "c")
    endif
    call add(keys, "C")
    call add(keys, "e")
    call add(keys, "E")
    call add(keys, "R")
    call add(keys, "m")
    call add(keys, "a")
    call add(keys, "A")
    call add(keys, "^p")
    call add(keys, "^n")
    call add(keys, "S")
    call add(keys, "l")
  endif

  return join(keys, separator)
endfunction

function! controlspace#statusline_info_segment(...)
  let statusline_elements = []

  if s:file_mode
    call add(statusline_elements, g:controlspace_symbols.add)
  elseif s:session_mode == 1
    call add(statusline_elements, g:controlspace_symbols.load)
  elseif s:session_mode == 2
    call add(statusline_elements, g:controlspace_symbols.save)
  elseif s:single_tab_mode
    call add(statusline_elements, g:controlspace_symbols.tab)
  else
    call add(statusline_elements, g:controlspace_symbols.all)
  endif

  if !s:session_mode
    if empty(s:search_letters) && !s:search_mode
      if exists("t:sort_order") && !s:file_mode
        if t:sort_order == 1
          call add(statusline_elements, g:controlspace_symbols.ord)
        elseif t:sort_order == 2
          call add(statusline_elements, g:controlspace_symbols.abc)
        endif
      endif
    else
      let search_element = g:controlspace_symbols.s_left . join(s:search_letters, "")

      if s:search_mode
        let search_element .= "_"
      endif

      let search_element .= g:controlspace_symbols.s_right

      call add(statusline_elements, search_element)
    endif

    if s:preview_mode
      call add(statusline_elements, g:controlspace_symbols.prv)
    endif
  endif

  let separator = (a:0 > 0) ? a:1 : "  "
  return join(statusline_elements, separator)
endfunction

function! controlspace#tabline()
  let last_tab    = tabpagenr("$")
  let current_tab = tabpagenr()
  let tabline     = ''

  for t in range(1, last_tab)
    let winnr               = tabpagewinnr(t)
    let buflist             = tabpagebuflist(t)
    let bufnr               = buflist[winnr - 1]
    let bufname             = bufname(bufnr)
    let bufs_number         = len(controlspace#bufferlist(t))
    let bufs_number_to_show = ""

    if bufs_number > 1
      if g:controlspace_unicode_font
        let small_numbers = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
        let number_str    = string(bufs_number)

        for i in range(0, len(number_str) - 1)
          let bufs_number_to_show .= small_numbers[str2nr(number_str[i])]
        endfor
      else
        let bufs_number_to_show = ":" . bufs_number
      endif
    endif

    let title = gettabvar(t, "controlspace_label")

    if empty(title)
      if bufname ==# "__CS__"
        if s:preview_mode && exists("s:preview_mode_orginal_buffer")
          let bufnr = s:preview_mode_orginal_buffer
        else
          let bufnr = winbufnr(t:controlspace_start_window)
        endif

        let bufname = bufname(bufnr)
      endif

      if empty(bufname)
        let title = "[" . bufnr . "*No Name]"
      else
        let title = "[" . fnamemodify(bufname, ':t') . "]"
      endif
    endif

    let tabline .= '%' . t . 'T'
    let tabline .= (t == current_tab ? '%#TabLineSel#' : '%#TabLine#')
    let tabline .= ' ' . t . bufs_number_to_show . ' '

    if <SID>tab_contains_modified_buffers(t)
      let tabline .= '+ '
    endif

    let tabline .= title . ' '
  endfor

  let tabline .= '%#TabLineFill#%T'

  if last_tab > 1
    let tabline .= '%='
    let tabline .= '%#TabLine#%999XX'
  endif

  return tabline
endfunction

function! <SID>new_tab_label()
  let t:controlspace_label = <SID>get_input("Label for tab " . tabpagenr() . ": ", exists("t:controlspace_label") ? t:controlspace_label : "")
endfunction

function! <SID>tab_contains_modified_buffers(tabnr)
  for b in map(keys(controlspace#bufferlist(a:tabnr)), "str2nr(v:val)")
    if getbufvar(b, '&modified')
      return 1
    endif
  endfor
  return 0
endfunction

function! <SID>max_height()
  if g:controlspace_max_height
    return g:controlspace_max_height
  else
    return &lines / 3
  endif
endfunction

function! <SID>session_file()
  for candidate in g:controlspace_session_file
    if isdirectory(fnamemodify(candidate, ":h:t"))
      return candidate
    endif
  endfor

  return g:controlspace_session_file[-1]
endfunction

function! <SID>save_first_session()
  let labels = []

  for t in range(1, tabpagenr("$"))
    let label = gettabvar(t, "controlspace_label")
    if !empty(label)
      call add(labels, gettabvar(t, "controlspace_label"))
    endif
  endfor

  call <SID>save_session(join(labels, " "))
endfunction

function! <SID>create_session_digest()
  let lines = []

  for t in range(1, tabpagenr("$"))
    let line = [t, gettabvar(t, "controlspace_label")]
    let bufs = []

    for bname in values(controlspace#bufferlist(t))
      let bufname = fnamemodify(bname, ":.")

      if !filereadable(bufname)
        continue
      endif

      call add(bufs, bufname)
    endfor
    call add(line, join(bufs, "|"))
    call add(lines, join(line, ","))
  endfor

  return join(lines, "&&&")
endfunction

function! <SID>save_session(name)
  let name = <SID>get_input("Save current session as: ", a:name)

  if empty(name)
    return
  endif

  call <SID>kill(0, 1)

  let filename = <SID>session_file()
  let last_tab = tabpagenr("$")

  let lines      = []
  let in_session = 0

  let session_start_marker = "CS_SESSION_BEGIN: " . name
  let session_end_marker   = "CS_SESSION_END: " . name

  if filereadable(filename)
    for old_line in readfile(filename)
      if old_line ==? session_start_marker
        let in_session = 1
      endif

      if !in_session
        call add(lines, old_line)
      endif

      if old_line ==? session_end_marker
        let in_session = 0
      endif
    endfor
  endif

  call add(lines, session_start_marker)

  for t in range(1, last_tab)
    let line = [t, gettabvar(t, "controlspace_label"), tabpagenr() == t]

    let controlspace_list = controlspace#bufferlist(t)

    let bufs     = []
    let visibles = []

    let visible_buffers = tabpagebuflist(t)

    let controlspace_list_index = -1

    for [nr, bname] in items(controlspace_list)
      let controlspace_list_index += 1
      let bufname = fnamemodify(bname, ":.")
      let nr = str2nr(nr)

      if !filereadable(bufname)
        continue
      endif

      if index(visible_buffers, nr) != -1
        call add(visibles, controlspace_list_index)
      endif

      call add(bufs, bufname)
    endfor

    call add(line, join(bufs, "|"))
    call add(line, join(visibles, "|"))
    call add(lines, join(line, ","))
  endfor

  call add(lines, session_end_marker)

  call writefile(lines, filename)

  let s:active_session_name   = name
  let s:active_session_digest = <SID>create_session_digest()
  let s:session_names         = []

  echo g:controlspace_symbols.cs . " - The session '" . name . "' has been saved."
endfunction

function! <SID>delete_session(name)
  if !<SID>confirmed("Delete session '" . a:name . "'?")
    return
  endif

  let filename = <SID>session_file()
  let last_tab = tabpagenr("$")

  let lines      = []
  let in_session = 0

  let session_start_marker = "CS_SESSION_BEGIN: " . a:name
  let session_end_marker   = "CS_SESSION_END: " . a:name

  if filereadable(filename)
    for old_line in readfile(filename)
      if old_line ==? session_start_marker
        let in_session = 1
      endif

      if !in_session
        call add(lines, old_line)
      endif

      if old_line ==? session_end_marker
        let in_session = 0
      endif
    endfor
  endif

  call writefile(lines, filename)

  if s:active_session_name ==? a:name
    let s:active_session_name   = ""
    let s:active_session_digest = ""
  endif

  echo g:controlspace_symbols.cs . " - The session '" . a:name . "' has been deleted."

  let s:session_names = []

  if empty(<SID>get_session_names())
    call <SID>kill(0, 1)
  else
    call <SID>kill(0, 0)
    call <SID>controlspace_toggle(1)
  endif
endfunction

function! <SID>get_session_names()
  let filename = <SID>session_file()

  let names = []

  if filereadable(filename)
    for line in readfile(filename)
      if line =~? "CS_SESSION_BEGIN: "
        call add(names, line[18:])
      endif
    endfor
  endif

  return names
endfunction

function! <SID>get_selected_session_name()
  return s:session_names[<SID>get_selected_buffer() - 1]
endfunction

function! <SID>get_input(msg, ...)
  let msg = g:controlspace_symbols.cs . " - " . a:msg

  call inputsave()

  if a:0 >= 2
    let answer = input(msg, a:1, a:2)
  elseif a:0 == 1
    let answer = input(msg, a:1)
  else
    let answer = input(msg)
  endif

  call inputrestore()
  redraw!

  return answer
endfunction

function! <SID>confirmed(msg)
  return <SID>get_input(a:msg . " (type 'yes' to confirm): ") ==? "yes"
endfunction

function! <SID>load_session(bang, name)
  if !empty(s:active_session_name) && a:bang
    let msg = ""

    if a:name == s:active_session_name
      let msg = "Reload current session: '" . a:name . "'?"
    elseif !empty(s:active_session_name)
      if s:active_session_digest !=# <SID>create_session_digest()
        let msg = "Current session not saved. Proceed anyway?"
      endif
    endif

    if !empty(msg) && !<SID>confirmed(msg)
      return
    endif
  endif

  let filename = <SID>session_file()

  if !filereadable(filename)
    echo g:controlspace_symbols.cs . " - Sessions file '" . filename . "' not found."
    call <SID>kill(0, 1)
    return
  endif

  let session_start_marker = "CS_SESSION_BEGIN: " . a:name
  let session_end_marker   = "CS_SESSION_END: " . a:name

  let lines      = []
  let in_session = 0

  for old_line in readfile(filename)
    if old_line ==? session_start_marker
      let in_session = 1
    elseif old_line ==? session_end_marker
      let in_session = 0
    elseif in_session
      call add(lines, old_line)
    endif
  endfor

  if empty(lines)
    echo g:controlspace_symbols.cs . " - Session '" . a:name . "' not found in file '" . filename . "'."
    let s:session_names = []
    call <SID>kill(0, 1)
    return
  endif

  call <SID>kill(0, 1)

  let commands = []

  if a:bang
    echo g:controlspace_symbols.cs . " - Loading session '" . a:name . "'..."
    call add(commands, "tabe")
    call add(commands, "tabo!")
    call add(commands, "call <SID>delete_hidden_noname_buffers(1)")
    call add(commands, "call <SID>delete_foreign_buffers(1)")

    let create_first_tab      = 0
    let s:active_session_name = a:name
  else
    echo g:controlspace_symbols.cs . " - Appending session '" . a:name . "'..."
    let create_first_tab = 1
  endif

  for line in lines
    let tab_data   = split(line, ",")
    let tabnr      = tab_data[0]
    let tab_label  = tab_data[1]
    let is_current = str2nr(tab_data[2])
    let files      = split(tab_data[3], "|")
    let visibles   = (len(tab_data) > 4) ? split(tab_data[4], "|") : []

    let readable_files = []
    let visible_files  = []

    let index = 0

    for fname in files
      if filereadable(fname)
        call add(readable_files, fname)

        if index(visibles, string(index)) > -1
          call add(visible_files, fname)
        endif
      endif

      let index += 1
    endfor

    if empty(readable_files)
      continue
    endif

    if create_first_tab
      call add(commands, "tabe")
    else
      let create_first_tab = 1 " we want omit only first tab creation if a:bang == 1
    endif

    for fname in readable_files
      call add(commands, "e " . fname)
      " jump to the last edited line
      call add(commands, "if line(\"'\\\"\") > 0 | " .
            \ "if line(\"'\\\"\") <= line('$') | " .
            \ "exe(\"norm '\\\"\") | else | exe 'norm $' | " .
            \ "endif | endif")
      call add(commands, "normal! zbze")
    endfor

    if !empty(visible_files)
      call add(commands, "e " . visible_files[0])

      for visible_fname in visible_files[1:-1]
        call add(commands, "vs " . visible_fname)
      endfor
    endif

    if is_current
      call add(commands, "let controlspace_session_current_tab = tabpagenr()")
    endif

    if !empty(tab_label)
      call add(commands, "let t:controlspace_label = '" . tab_label . "'")
    endif
  endfor

  call add(commands, "exe 'normal! ' . controlspace_session_current_tab . 'gt'")
  call add(commands, "redraw!")

  for c in commands
    silent! exe c
  endfor


  if a:bang
    echo g:controlspace_symbols.cs . " - The session '" . a:name . "' has been loaded."
    let s:active_session_digest = <SID>create_session_digest()
  else
    let s:active_session_digest = ""
    echo g:controlspace_symbols.cs . " - The session '" . a:name . "' has been appended."
    call <SID>controlspace_toggle(0)
    let s:session_mode = 1
    call <SID>kill(0, 0)
    call <SID>controlspace_toggle(1)
  endif
endfunction

function! <SID>find_subsequence(bufname, offset)
  let positions      = []
  let noise          = 0
  let current_offset = a:offset

  for letter in s:search_letters
    let matched_position = match(a:bufname, "\\m\\c" . letter, current_offset)

    if matched_position == -1
      return [-1, []]
    else
      if !empty(positions)
        let noise += abs(matched_position - positions[-1]) - 1
      endif
      call add(positions, matched_position)
      let current_offset = matched_position + 1
    endif
  endfor

  return [noise, positions]
endfunction

function! <SID>find_lowest_search_noise(bufname)
  if has("ruby") && g:controlspace_use_ruby_bindings
    ruby VIM.command("return #{ControlSpace.find_lowest_search_noise(VIM.evaluate('a:bufname'))}")
  else
    let search_letters_count = len(s:search_letters)
    let noise                = -1
    let matched_string       = ""

    if search_letters_count == 0
      return 0
    elseif search_letters_count == 1
      let noise          = match(a:bufname, "\\m\\c" . s:search_letters[0])
      let matched_string = s:search_letters[0]
    else
      let offset      = 0
      let bufname_len = strlen(a:bufname)

      while offset < bufname_len
        let subseq = <SID>find_subsequence(a:bufname, offset)

        if subseq[0] == -1
          break
        elseif (noise == -1) || (subseq[0] < noise)
          let noise          = subseq[0]
          let offset         = subseq[1][0] + 1
          let matched_string = a:bufname[subseq[1][0]:subseq[1][-1]]
        else
          let offset += 1
        endif
      endwhile
    endif

    if (noise > -1) && !empty(matched_string)
      let b:search_patterns[matched_string] = 1
    endif

    return noise
  endif
endfunction

function! <SID>display_search_patterns()
  for pattern in keys(b:search_patterns)
    call matchadd("ControlSpaceFound", "\\c" . pattern)
  endfor
endfunction

function! <SID>append_to_search_history()
  if !empty(s:search_letters)
    if !exists("t:controlspace_search_history")
      let t:controlspace_search_history = []
    endif

    call add(t:controlspace_search_history, copy(s:search_letters))
    let t:controlspace_search_history = <SID>unique_list(t:controlspace_search_history)

    if len(t:controlspace_search_history) > g:controlspace_max_searches + 1
      unlet t:controlspace_jumps[0]
    endif
  endif
endfunction

function! <SID>restore_search_letters(direction)
  if !exists("t:controlspace_search_history")
    return
  endif

  if a:direction == "previous"
    let t:controlspace_search_history_index += 1

    if t:controlspace_search_history_index == len(t:controlspace_search_history)
      let t:controlspace_search_history_index = len(t:controlspace_search_history) - 1
    endif
  elseif a:direction == "next"
    let t:controlspace_search_history_index -= 1

    if t:controlspace_search_history_index < -1
      let t:controlspace_search_history_index = -1
    endif
  endif

  if t:controlspace_search_history_index < 0
    let s:search_letters = []
  else
    let s:search_letters = copy(reverse(copy(t:controlspace_search_history))[t:controlspace_search_history_index])
    let s:restored_search_mode = 1
  endif

  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>prepare_buflist_to_display(buflist)
  for entry in a:buflist
    let bufname = entry.raw

    if strlen(bufname) + 6 > &columns
      if g:controlspace_unicode_font
        let dots_symbol = "…"
        let dots_symbol_size = 1
      else
        let dots_symbol = "..."
        let dots_symbol_size = 3
      endif

      let bufname = dots_symbol . strpart(bufname, strlen(bufname) - &columns + 6 + dots_symbol_size)
    endif

    if !s:file_mode && !s:session_mode
      let bufname = <SID>decorate_with_indicators(bufname, entry.number)
    elseif s:session_mode
      if entry.raw ==# s:active_session_name
        let bufname .= g:controlspace_unicode_font ? " ★" : " *"

        if s:active_session_digest !=# <SID>create_session_digest()
          let bufname .= "+"
        endif
      endif
    endif

    while strlen(bufname) < &columns
      let bufname .= " "
    endwhile

    " handle wrong strlen for unicode dots symbol
    if g:controlspace_unicode_font && bufname =~ "…"
      let bufname .= "  "
    endif

    let entry.text = "  " . bufname . "\n"
  endfor
endfunction

" toggled the buffer list on/off
function! <SID>controlspace_toggle(internal)
  if !a:internal
    let s:single_tab_mode         = 1
    let s:nop_mode                = 0
    let s:new_search_performed    = 0
    let s:search_mode             = 0
    let s:file_mode               = 0
    let s:session_mode            = 0
    let s:last_browsed_session    = 0
    let s:restored_search_mode    = 0
    let s:search_letters          = []
    let t:controlspace_search_history_index = -1

    if !exists("t:sort_order")
      let t:sort_order = g:controlspace_default_sort_order
    endif
  endif

  " if we get called and the list is open --> close it
  let buflistnr = bufnr("__CS__")
  if bufexists(buflistnr)
    if bufwinnr(buflistnr) != -1
      call <SID>kill(buflistnr, 1)
      return
    else
      call <SID>kill(buflistnr, 0)
      if !a:internal
        let t:controlspace_start_window = winnr()
        let t:controlspace_winrestcmd = winrestcmd()
      endif
    endif
  elseif !a:internal
    let t:controlspace_start_window = winnr()
    let t:controlspace_winrestcmd = winrestcmd()
  endif

  let bufcount      = bufnr('$')
  let displayedbufs = 0
  let activebuf     = bufnr('')
  let buflist       = []

  " create the buffer first & set it up
  silent! exe "noautocmd botright pedit __CS__"
  silent! exe "noautocmd wincmd P"
  silent! exe "resize" g:controlspace_height

  call <SID>set_up_buffer()

  if s:file_mode
    if empty(s:files)
      echo g:controlspace_symbols.cs . " - Collecting files..."

      let s:files = []
      let s:all_files_cached = []
      let i = 1

      for fname in split(globpath('.', '**'), '\n')
        let fname_modified = fnamemodify(fname, ":.")

        if isdirectory(fname_modified) || (fname_modified =~# g:controlspace_ignored_files)
          continue
        endif

        call add(s:files, fname_modified)
        call add(s:all_files_cached, { "number": i, "raw": fname_modified, "search_noise": 0 })
        let i += 1
      endfor

      call <SID>prepare_buflist_to_display(s:all_files_cached)
      call sort(s:all_files_cached, function(<SID>SID() . "compare_file_entries"))

      redraw!
      echo g:controlspace_symbols.cs . " - Collecting files... Done (" . len(s:files) . ")."
    endif

    let bufcount = len(s:files)
  elseif s:session_mode
    if empty(s:session_names)
      let s:session_names = <SID>get_session_names()
    endif

    let bufcount = len(s:session_names)
  endif

  if s:file_mode && empty(s:search_letters)
    let buflist = s:all_files_cached
    let displayedbufs = len(buflist)
  else
    for i in range(1, bufcount)
      if s:file_mode
        let bufname = s:files[i - 1]
      elseif s:session_mode
        let bufname = s:session_names[i - 1]
      else
        if s:single_tab_mode && !exists('t:controlspace_list[' . i . ']')
          continue
        endif

        let bufname = fnamemodify(bufname(i), ":.")

        if g:controlspace_show_unnamed && !strlen(bufname)
          if !((g:controlspace_show_unnamed == 2) && !getbufvar(i, '&modified')) || (bufwinnr(i) != -1)
            let bufname = '[' . i . '*No Name]'
          endif
        endif
      endif

      if strlen(bufname) && (s:file_mode || s:session_mode || (getbufvar(i, '&modifiable') && getbufvar(i, '&buflisted')))
        let search_noise = <SID>find_lowest_search_noise(bufname)

        if search_noise == -1
          continue
        endif

        " count displayed buffers
        let displayedbufs += 1

        call add(buflist, { "number": i, "raw": bufname, "search_noise": search_noise })
      endif
    endfor
  endif

  " set up window height
  if displayedbufs > g:controlspace_height
    if displayedbufs < <SID>max_height()
      silent! exe "resize " . displayedbufs
    else
      silent! exe "resize " . <SID>max_height()
    endif
  endif

  call <SID>display_list(displayedbufs, buflist)
  call <SID>set_status_line()

  if !empty(s:search_letters)
    call <SID>display_search_patterns()
  endif

  if s:session_mode
    if s:last_browsed_session
      let activebufline = s:last_browsed_session
    else
      let activebufline = 1

      if !empty(s:active_session_name)
        let active_session_line = 0

        for session_name in buflist
          let active_session_line += 1

          if s:active_session_name ==# session_name.raw
            let activebufline = active_session_line
            break
          endif
        endfor
      endif
    endif
  else
    let activebufline = s:file_mode ? line("$") : <SID>find_activebufline(activebuf, buflist)
  endif

  " make the buffer count & the buffer numbers available
  " for our other functions
  let b:buflist = buflist
  let b:bufcount = displayedbufs

  if !s:file_mode && !s:session_mode
    let b:jumplines = <SID>create_jumplines(buflist, activebufline)
  endif

  " go to the correct line
  if !empty(s:search_letters) && s:new_search_performed
    call<SID>move(line("$"))
    if !s:search_mode
      let s:new_search_performed = 0
    endif
  else
    call <SID>move(activebufline)
  endif
  normal! zb
endfunction

function! <SID>create_jumplines(buflist, activebufline)
  let buffers = []
  for bufentry in a:buflist
    call add(buffers, bufentry.number)
  endfor

  if s:single_tab_mode && exists("t:controlspace_jumps")
    let bufferjumps = t:controlspace_jumps
  else
    let bufferjumps = s:controlspace_jumps
  endif

  let jumplines = []

  for jumpbuf in bufferjumps
    if bufwinnr(jumpbuf) == -1
      let jumpline = index(buffers, jumpbuf)
      if (jumpline >= 0)
        call add(jumplines, jumpline + 1)
      endif
    endif
  endfor

  call add(jumplines, a:activebufline)

  return reverse(<SID>unique_list(jumplines))
endfunction

function! <SID>clear_search_mode()
  let s:search_letters          = []
  let s:search_mode             = 0
  let t:controlspace_search_history_index = -1

  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>add_search_letter(letter)
  call add(s:search_letters, a:letter)
  let s:new_search_performed = 1
  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>remove_search_letter()
  call remove(s:search_letters, -1)
  let s:new_search_performed = 1
  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>switch_search_mode(switch)
  if (a:switch == 0) && !empty(s:search_letters)
    call <SID>append_to_search_history()
  endif

  let s:search_mode = a:switch

  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>unique_list(list)
  return filter(copy(a:list), 'index(a:list, v:val, v:key + 1) == -1')
endfunction

function! <SID>decorate_with_indicators(name, bufnum)
  let indicators = ' '

  if s:preview_mode && (s:preview_mode_orginal_buffer == a:bufnum)
    let indicators .= g:controlspace_unicode_font ? "☆" : "*"
  elseif bufwinnr(a:bufnum) != -1
    let indicators .= g:controlspace_unicode_font ? "★" : "*"
  endif

  if getbufvar(a:bufnum, "&modified")
    let indicators .= "+"
  endif

  if len(indicators) > 1
    return a:name . indicators
  else
    return a:name
  endif
endfunction

function! <SID>find_activebufline(activebuf, buflist)
  let activebufline = 0

  for bufentry in a:buflist
    let activebufline += 1
    if a:activebuf == bufentry.number
      return activebufline
    endif
  endfor

  return activebufline
endfunction

function! <SID>go_to_start_window()
  if exists("t:controlspace_start_window")
    silent! exe t:controlspace_start_window . "wincmd w"
  endif

  if exists("t:controlspace_winrestcmd") && (winrestcmd() != t:controlspace_winrestcmd)
    silent! exe t:controlspace_winrestcmd

    if winrestcmd() != t:controlspace_winrestcmd
      wincmd =
    endif
  endif
endfunction

function! <SID>kill(buflistnr, final)
  if exists("s:killing_now") && s:killing_now
    return
  endif

  let s:killing_now = 1

  if a:buflistnr
    silent! exe ':' . a:buflistnr . 'bwipeout'
  else
    bwipeout
  endif

  if a:final
    if s:restored_search_mode
      call <SID>append_to_search_history()
    endif

    call <SID>go_to_start_window()

    if s:preview_mode
      exec ":b " . s:preview_mode_orginal_buffer
      unlet s:preview_mode_orginal_buffer
      let s:preview_mode = 0
    endif
  endif

  unlet s:killing_now
endfunction

function! <SID>tab_command(key)
  call <SID>kill(0, 1)

  if a:key ==# "T"
    silent! exe "tabnew"
  elseif a:key ==# "["
    silent! exe "normal! gT"
  elseif a:key ==# "]"
    silent! exe "normal! gt"
  else
    let tab_nr   = str2nr((a:key == "0") ? "10" : a:key)
    let last_tab = tabpagenr("$")

    if tab_nr > last_tab
      let tab_nr = last_tab
    endif

    silent! exe "normal! " . tab_nr . "gt"
  endif

  call <SID>controlspace_toggle(0)
endfunction

function! <SID>keypressed(key)
  if a:key ==# "?"
    let g:controlspace_show_key_info = !g:controlspace_show_key_info
    call <SID>set_status_line()
    redraw!
    return
  endif

  if s:nop_mode
    if !s:search_mode
      if a:key ==# "a"
        if s:file_mode
          call <SID>toggle_file_mode()
        else
          call <SID>toggle_single_tab_mode()
        endif
      elseif a:key ==# "A"
        call <SID>toggle_file_mode()
      elseif a:key ==# "q"
        call <SID>kill(0, 1)
      elseif a:key ==# "C-p"
        call <SID>restore_search_letters("previous")
      elseif a:key ==# "C-n"
        call <SID>restore_search_letters("next")
      endif
    endif

    if a:key ==# "BS"
      if s:search_mode
        if empty(s:search_letters)
          call <SID>clear_search_mode()
        else
          call <SID>remove_search_letter()
        endif
      elseif !empty(s:search_letters)
        call <SID>clear_search_mode()
      endif
    endif
    return
  endif

  if s:search_mode
    if a:key ==# "BS"
      if empty(s:search_letters)
        call <SID>clear_search_mode()
      else
        call <SID>remove_search_letter()
      endif
    elseif (a:key ==# "/") || (a:key ==# "CR") || (s:file_mode && a:key ==# "BSlash")
      call <SID>switch_search_mode(0)
    elseif a:key =~? "^[A-Z0-9]$"
      call <SID>add_search_letter(a:key)
    endif
  elseif s:session_mode == 1
    if a:key ==# "CR"
      call <SID>load_session(1, <SID>get_selected_session_name())
    elseif a:key ==# "q"
      call <SID>kill(0, 1)
    elseif a:key ==# "a"
      call <SID>load_session(0, <SID>get_selected_session_name())
    elseif a:key ==# "s"
      let s:last_browsed_session = line(".")
      call <SID>kill(0, 0)
      let s:session_mode = 2
      call <SID>controlspace_toggle(1)
    elseif a:key ==# "S"
      call <SID>save_session(s:active_session_name)
    elseif (a:key ==# "l") || (a:key ==# "BS")
      let s:last_browsed_session = line(".")
      call <SID>kill(0, 0)
      let s:session_mode = 0
      call <SID>controlspace_toggle(1)
    elseif a:key ==# "d"
      call <SID>delete_session(<SID>get_selected_session_name())
    elseif a:key ==# "j"
      call <SID>move("down")
    elseif a:key ==# "k"
      call <SID>move("up")
    elseif a:key ==# "MouseDown"
      call <SID>move("up")
    elseif a:key ==# "MouseUp"
      call <SID>move("down")
    elseif a:key ==# "LeftRelease"
      call <SID>move("mouse")
    elseif a:key ==# "2-LeftMouse"
      call <SID>move("mouse")
      call <SID>load_session(1, <SID>get_selected_session_name())
    elseif a:key ==# "Down"
      call feedkeys("j")
    elseif a:key ==# "Up"
      call feedkeys("k")
    elseif (a:key ==# "Home") || (a:key ==# "K")
      call <SID>move(1)
    elseif (a:key ==# "End") || (a:key ==# "J")
      call <SID>move(line("$"))
    endif
  elseif s:session_mode == 2
    if a:key ==# "CR"
      call <SID>save_session(<SID>get_selected_session_name())
    elseif a:key ==# "q"
      call <SID>kill(0, 1)
    elseif a:key ==# "s"
      let s:last_browsed_session = line(".")
      call <SID>kill(0, 0)
      let s:session_mode = 1
      call <SID>controlspace_toggle(1)
    elseif a:key ==# "S"
      call <SID>save_session(s:active_session_name)
    elseif (a:key ==# "l") || (a:key ==# "BS")
      let s:last_browsed_session = line(".")
      call <SID>kill(0, 0)
      let s:session_mode = 0
      call <SID>controlspace_toggle(1)
    elseif a:key ==# "d"
      call <SID>delete_session(<SID>get_selected_session_name())
    elseif a:key ==# "j"
      call <SID>move("down")
    elseif a:key ==# "k"
      call <SID>move("up")
    elseif a:key ==# "MouseDown"
      call <SID>move("up")
    elseif a:key ==# "MouseUp"
      call <SID>move("down")
    elseif a:key ==# "LeftRelease"
      call <SID>move("mouse")
    elseif a:key ==# "2-LeftMouse"
      call <SID>move("mouse")
      call <SID>save_session(<SID>get_selected_session_name())
    elseif a:key ==# "Down"
      call feedkeys("j")
    elseif a:key ==# "Up"
      call feedkeys("k")
    elseif (a:key ==# "Home") || (a:key ==# "K")
      call <SID>move(1)
    elseif (a:key ==# "End") || (a:key ==# "J")
      call <SID>move(line("$"))
    endif
  elseif s:file_mode
    if a:key ==# "CR"
      call <SID>load_file()
    elseif a:key ==# "Space"
      call <SID>load_many_files()
    elseif a:key ==# "BS"
      if !empty(s:search_letters)
        call <SID>clear_search_mode()
      else
        call <SID>toggle_file_mode()
      endif
    elseif (a:key ==# "/") || (a:key ==# "BSlash")
      call <SID>switch_search_mode(1)
    elseif a:key ==# "v"
      call <SID>load_file("vs")
    elseif a:key ==# "s"
      call <SID>load_file("sp")
    elseif a:key ==# "t"
      call <SID>load_file("tabnew")
    elseif a:key ==# "T"
      call <SID>tab_command(a:key)
    elseif a:key ==# "="
      call <SID>new_tab_label()
    elseif a:key =~? "^[0-9]$"
      call <SID>tab_command(a:key)
    elseif a:key ==# "+"
      silent! exe "tabm+1"
    elseif a:key ==# "-"
      silent! exe "tabm-1"
    elseif a:key ==# "_"
      let t:controlspace_label = ""
      redraw!
    elseif a:key ==# "["
      call <SID>tab_command(a:key)
    elseif a:key ==# "]"
      call <SID>tab_command(a:key)
    elseif a:key ==# "r"
      call <SID>refresh_files()
    elseif a:key ==# "q"
      call <SID>kill(0, 1)
    elseif a:key ==# "j"
      call <SID>move("down")
    elseif a:key ==# "k"
      call <SID>move("up")
    elseif a:key ==# "MouseDown"
      call <SID>move("up")
    elseif a:key ==# "MouseUp"
      call <SID>move("down")
    elseif a:key ==# "LeftRelease"
      call <SID>move("mouse")
    elseif a:key ==# "2-LeftMouse"
      call <SID>move("mouse")
      call <SID>load_file()
    elseif a:key ==# "Down"
      call feedkeys("j")
    elseif a:key ==# "Up"
      call feedkeys("k")
    elseif (a:key ==# "Home") || (a:key ==# "K")
      call <SID>move(1)
    elseif (a:key ==# "End") || (a:key ==# "J")
      call <SID>move(line("$"))
    elseif a:key ==? "A"
      call <SID>toggle_file_mode()
    elseif a:key ==# "C-p"
      call <SID>restore_search_letters("previous")
    elseif a:key ==# "C-n"
      call <SID>restore_search_letters("next")
    elseif a:key ==# "C"
      call <SID>close_tab()
    elseif a:key ==# "e"
      call <SID>edit_file()
    elseif a:key ==# "E"
      call <SID>explore_directory()
    elseif a:key ==# "R"
      call <SID>remove_file()
    elseif a:key ==# "m"
      call <SID>move_file()
    elseif a:key ==# "l"
      if empty(<SID>get_session_names())
        call <SID>save_first_session()
      else
        call <SID>kill(0, 0)
        let s:file_mode = !s:file_mode
        let s:session_mode = 1
        call <SID>controlspace_toggle(1)
      endif
    endif
  else
    if a:key ==# "CR"
      call <SID>load_buffer()
    elseif a:key ==# "Space"
      call <SID>load_many_buffers()
    elseif (a:key ==# "Tab")
      call <SID>preview_buffer(0)
    elseif a:key ==# "BS"
      if !empty(s:search_letters)
        call <SID>clear_search_mode()
      elseif !s:single_tab_mode
        call <SID>toggle_single_tab_mode()
      else
        call <SID>kill(0, 1)
      endif
    elseif a:key ==# "/"
      call <SID>switch_search_mode(1)
    elseif a:key ==# "v"
      call <SID>load_buffer("vs")
    elseif a:key ==# "s"
      call <SID>load_buffer("sp")
    elseif a:key ==# "t"
      call <SID>load_buffer("tabnew")
    elseif a:key ==# "T"
      call <SID>tab_command(a:key)
    elseif a:key ==# "="
      call <SID>new_tab_label()
    elseif a:key =~? "^[0-9]$"
      call <SID>tab_command(a:key)
    elseif a:key ==# "+"
      silent! exe "tabm+1"
    elseif a:key ==# "-"
      silent! exe "tabm-1"
    elseif a:key ==# "_"
      let t:controlspace_label = ""
      redraw!
    elseif a:key ==# "["
      call <SID>tab_command(a:key)
    elseif a:key ==# "]"
      call <SID>tab_command(a:key)
    elseif a:key ==# "o" && empty(s:search_letters)
      call <SID>toggle_order()
    elseif a:key ==# "q"
      call <SID>kill(0, 1)
    elseif a:key ==# "j"
      call <SID>move("down")
    elseif a:key ==# "k"
      call <SID>move("up")
    elseif a:key ==# "p"
      call <SID>jump("previous")
    elseif a:key ==# "P"
      call <SID>jump("previous")
      call <SID>load_buffer()
    elseif a:key ==# "n"
      call <SID>jump("next")
    elseif a:key ==# "d"
      call <SID>delete_buffer()
    elseif a:key ==# "D"
      call <SID>delete_hidden_noname_buffers(0)
    elseif a:key ==# "MouseDown"
      call <SID>move("up")
    elseif a:key ==# "MouseUp"
      call <SID>move("down")
    elseif a:key ==# "LeftRelease"
      call <SID>move("mouse")
    elseif a:key ==# "2-LeftMouse"
      call <SID>move("mouse")
      call <SID>load_buffer()
    elseif a:key ==# "Down"
      call feedkeys("j")
    elseif a:key ==# "Up"
      call feedkeys("k")
    elseif (a:key ==# "Home") || (a:key ==# "K")
      call <SID>move(1)
    elseif (a:key ==# "End") || (a:key ==# "J")
      call <SID>move(line("$"))
    elseif a:key ==# "a"
      call <SID>toggle_single_tab_mode()
    elseif a:key ==# "f" && s:single_tab_mode
      call <SID>detach_buffer()
    elseif a:key ==# "F"
      call <SID>delete_foreign_buffers(0)
    elseif a:key ==# "c" && s:single_tab_mode
      call <SID>close_buffer()
    elseif a:key ==# "C"
      call <SID>close_tab()
    elseif a:key ==# "e"
      call <SID>edit_file()
    elseif a:key ==# "E"
      call <SID>explore_directory()
    elseif a:key ==# "R"
      call <SID>remove_file()
    elseif a:key ==# "m"
      call <SID>move_file()
    elseif a:key ==# "S"
      if empty(<SID>get_session_names())
        call <SID>save_first_session()
      else
        call <SID>save_session(s:active_session_name)
      endif
    elseif a:key ==# "l"
      if empty(<SID>get_session_names())
        call <SID>save_first_session()
      else
        call <SID>kill(0, 0)
        let s:session_mode = 1
        call <SID>controlspace_toggle(1)
      endif
    elseif a:key ==# "A"
      call <SID>toggle_file_mode()
    elseif a:key ==# "C-p"
      call <SID>restore_search_letters("previous")
    elseif a:key ==# "C-n"
      call <SID>restore_search_letters("next")
    elseif a:key ==# "BSlash"
      call <SID>toggle_file_mode()
      call <SID>switch_search_mode(1)
    endif
  endif
endfunction

function! <SID>toggle_file_mode()
  if !s:file_mode && !empty(g:controlspace_project_root_markers)
    let marker_found = 0

    for marker in g:controlspace_project_root_markers
      if filereadable(marker) || isdirectory(marker)
        let marker_found = 1
        break
      endif
    endfor

    if !marker_found
      let project_root = fnamemodify(".", ":p")

      if index(s:project_roots, project_root) == -1
        if !<SID>confirmed("Project root not found. Do you really want to display '" . project_root . "'?")
          return
        endif

        call <SID>add_project_root(project_root)
      endif
    endif
  endif

  let s:file_mode = !s:file_mode

  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>set_status_line()
  if has('statusline')
    hi default link User1 LineNr
    let &l:statusline = "%1*\ \ " . g:controlspace_symbols.cs . "\ \ %*\ \ " . controlspace#statusline_info_segment()

    if g:controlspace_show_key_info
      let key_info = "  %=%1* " . controlspace#statusline_key_info_segment() . " "

      if strlen(&l:statusline) + strlen(key_info) > &columns
        let key_info = "  %=%1* ? ... "
      endif

      let &l:statusline .= key_info
    endif
  endif
endfunction

function! <SID>set_up_buffer()
  setlocal noshowcmd
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal nobuflisted
  setlocal nomodifiable
  setlocal nowrap
  setlocal nonumber
  setlocal nocursorcolumn
  setlocal nocursorline

  let b:search_patterns = {}

  if &timeout
    let b:old_timeoutlen = &timeoutlen
    set timeoutlen=10
    au BufEnter <buffer> set timeoutlen=10
    au BufLeave <buffer> silent! exe "set timeoutlen=" . b:old_timeoutlen
  endif

  augroup ControlSpaceLeave
    au!
    au BufLeave <buffer> call <SID>kill(0, 1)
  augroup END

  " set up syntax highlighting
  if has("syntax")
    syn clear
    syn match ControlSpaceNormal /  .*/
    syn match ControlSpaceSelected /> .*/hs=s+1

    hi def ControlSpaceNormal ctermfg=black ctermbg=white
    hi def ControlSpaceSelected ctermfg=white ctermbg=black
  endif

  call clearmatches()
  hi def ControlSpaceFound ctermfg=NONE ctermbg=NONE cterm=underline

  for key_name in s:key_names
    let key = strlen(key_name) > 1 ? ("<" . key_name . ">") : key_name
    silent! exe "noremap <silent><buffer> " . key . " :call <SID>keypressed(\"" . key_name . "\")<CR>"
  endfor
endfunction

function! <SID>make_filler()
  " generate a variable to fill the buffer afterwards
  " (we need this for "full window" color :)
  let fill = "\n"
  let i = 0 | while i < &columns | let i += 1
    let fill = ' ' . fill
  endwhile

  return fill
endfunction

function! <SID>compare_bufentries(a, b)
  if t:sort_order == 1
    if s:single_tab_mode
      if exists("t:controlspace_list[" . a:a.number . "]") && exists("t:controlspace_list[" . a:b.number . "]")
        return t:controlspace_list[a:a.number] - t:controlspace_list[a:b.number]
      endif
    endif
    return a:a.number - a:b.number
  elseif t:sort_order == 2
    if a:a.raw < a:b.raw
      return -1
    elseif a:a.raw > a:b.raw
      return 1
    else
      return 0
    endif
  endif
endfunction

function! <SID>compare_file_entries(a, b)
  if a:a.raw < a:b.raw
    return -1
  elseif a:a.raw > a:b.raw
    return 1
  else
    return 0
  endif
endfunction

function! <SID>compare_session_names(a, b)
  if a:a.raw < a:b.raw
    return -1
  elseif a:a.raw > a:b.raw
    return 1
  else
    return 0
  endif
endfunction

function! <SID>compare_bufentries_with_search_noise(a, b)
  if a:a.search_noise < a:b.search_noise
    return 1
  elseif a:a.search_noise > a:b.search_noise
    return -1
  elseif strlen(a:a.raw) < strlen(a:b.raw)
    return 1
  elseif strlen(a:a.raw) > strlen(a:b.raw)
    return -1
  elseif a:a.raw < a:b.raw
    return -1
  elseif a:a.raw > a:b.raw
    return 1
  else
    return 0
  endif
endfunction

function! <SID>SID()
  let fullname = expand("<sfile>")
  return matchstr(fullname, '<SNR>\d\+_')
endfunction

function! <SID>display_list(displayedbufs, buflist)
  setlocal modifiable
  if a:displayedbufs > 0
    if s:file_mode && empty(s:search_letters)
      let buflist = a:buflist
    else
      if !empty(s:search_letters)
        call sort(a:buflist, function(<SID>SID() . "compare_bufentries_with_search_noise"))
      elseif s:session_mode
        call sort(a:buflist, function(<SID>SID() . "compare_session_names"))
      elseif exists("t:sort_order")
        call sort(a:buflist, function(<SID>SID() . "compare_bufentries"))
      endif

      " trim the list in search mode
      let buflist = s:search_mode && (len(a:buflist) > <SID>max_height()) ? a:buflist[-<SID>max_height() : -1] : a:buflist

      call <SID>prepare_buflist_to_display(buflist)
    endif

    " input the buffer list, delete the trailing newline, & fill with blank lines
    let buftext = ""

    for bufentry in buflist
      let buftext .= bufentry.text
    endfor

    silent! put! =buftext
    " is there any way to NOT delete into a register? bummer...
    "normal! Gdd$
    normal! GkJ
    let fill = <SID>make_filler()
    while winheight(0) > line(".")
      silent! put =fill
    endwhile

    let s:nop_mode = 0
  else
    let empty_list_message = "  List empty"

    if &columns < (strlen(empty_list_message) + 2)
      if g:controlspace_unicode_font
        let dots_symbol = "…"
        let dots_symbol_size = 1
      else
        let dots_symbol = "..."
        let dots_symbol_size = 3
      endif

      let empty_list_message = strpart(empty_list_message, 0, &columns - 2 - dots_symbol_size) . dots_symbol
    endif

    while strlen(empty_list_message) < &columns
      let empty_list_message .= ' '
    endwhile

    " handle wrong strlen for unicode dots symbol
    if g:controlspace_unicode_font && empty_list_message =~ "…"
      let empty_list_message .= "  "
    endif

    silent! put! =empty_list_message
    normal! GkJ

    let fill = <SID>make_filler()

    while winheight(0) > line(".")
      silent! put =fill
    endwhile

    normal! 0

    " handle vim segfault on calling bd/bw if there are no buffers listed
    let any_buffer_listed = 0
    for i in range(1, bufnr("$"))
      if buflisted(i)
        let any_buffer_listed = 1
        break
      endif
    endfor

    if !any_buffer_listed
      au! ControlSpaceLeave BufLeave
      noremap <silent> <buffer> q :q<CR>
      if g:controlspace_set_default_mapping
        silent! exe 'noremap <silent><buffer>' . g:controlspace_default_mapping_key . ' :q<CR>'
      endif
    endif

    let s:nop_mode = 1
  endif
  setlocal nomodifiable
endfunction

" move the selection bar of the list:
" where can be "up"/"down"/"mouse" or
" a line number
function! <SID>move(where)
  if b:bufcount < 1
    return
  endif
  let newpos = 0
  if !exists('b:lastline')
    let b:lastline = 0
  endif
  setlocal modifiable

  " the mouse was pressed: remember which line
  " and go back to the original location for now
  if a:where == "mouse"
    let newpos = line(".")
    call <SID>goto(b:lastline)
  endif

  " exchange the first char (>) with a space
  call setline(line("."), " ".strpart(getline(line(".")), 1))

  " go where the user want's us to go
  if a:where == "up"
    call <SID>goto(line(".")-1)
  elseif a:where == "down"
    call <SID>goto(line(".")+1)
  elseif a:where == "mouse"
    call <SID>goto(newpos)
  else
    call <SID>goto(a:where)
  endif

  " and mark this line with a >
  call setline(line("."), ">".strpart(getline(line(".")), 1))

  " remember this line, in case the mouse is clicked
  " (which automatically moves the cursor there)
  let b:lastline = line(".")

  setlocal nomodifiable
endfunction

" tries to set the cursor to a line of the buffer list
function! <SID>goto(line)
  if b:bufcount < 1 | return | endif
  if a:line < 1
    if g:controlspace_cyclic_list
      call <SID>goto(b:bufcount - a:line)
    else
      call cursor(1, 1)
    endif
  elseif a:line > b:bufcount
    if g:controlspace_cyclic_list
      call <SID>goto(a:line - b:bufcount)
    else
      call cursor(b:bufcount, 1)
    endif
  else
    call cursor(a:line, 1)
  endif
endfunction

function! <SID>jump(direction)
  if !exists("b:jumppos")
    let b:jumppos = 0
  endif

  if a:direction == "previous"
    let b:jumppos += 1

    if b:jumppos == len(b:jumplines)
      let b:jumppos = len(b:jumplines) - 1
    endif
  elseif a:direction == "next"
    let b:jumppos -= 1

    if b:jumppos < 0
      let b:jumppos = 0
    endif
  endif

  call <SID>move(string(b:jumplines[b:jumppos]))
endfunction

function! <SID>load_many_buffers()
  let nr = <SID>get_selected_buffer()
  let current_line = line(".")

  call <SID>kill(0, 0)
  call <SID>go_to_start_window()

  exec ":b " . nr

  call <SID>controlspace_toggle(1)
  call <SID>move(current_line)
endfunction

function! <SID>load_buffer(...)
  let nr = <SID>get_selected_buffer()
  call <SID>kill(0, 1)

  if !empty(a:000)
    exec ":" . a:1
  endif

  exec ":b " . nr
endfunction

function! <SID>load_many_files()
  let file_number = <SID>get_selected_buffer()
  let file = s:files[file_number - 1]
  let current_line = line(".")

  call <SID>kill(0, 0)
  call <SID>go_to_start_window()

  exec ":e " . file

  call <SID>controlspace_toggle(1)
  call <SID>move(current_line)
endfunction

function! <SID>load_file(...)
  let file_number = <SID>get_selected_buffer()
  let file = s:files[file_number - 1]

  call <SID>kill(0, 1)

  if !empty(a:000)
    exec ":" . a:1
  endif

  exec ":e " . file
endfunction

function! <SID>preview_buffer(nr, ...)
  if !s:preview_mode
    let s:preview_mode = 1
    let s:preview_mode_orginal_buffer = winbufnr(t:controlspace_start_window)
  endif

  let nr = a:nr ? a:nr : <SID>get_selected_buffer()

  call <SID>kill(0, 0)

  call <SID>go_to_start_window()
  silent! exe ":b " . nr

  let custom_commands = !empty(a:000) ? a:1 : ["normal! zb"]

  for c in custom_commands
    silent! exe c
  endfor

  call <SID>controlspace_toggle(1)
endfunction

function! <SID>load_buffer_into_window(winnr)
  if exists("t:controlspace_start_window")
    let old_start_window = t:controlspace_start_window
    let t:controlspace_start_window = a:winnr
  endif
  call <SID>load_buffer()
  if exists("old_start_window")
    let t:controlspace_start_window = old_start_window
  endif
endfunction

" deletes the selected buffer
function! <SID>delete_buffer()
  let nr = <SID>get_selected_buffer()
  if !getbufvar(str2nr(nr), '&modified')
    let selected_buffer_window = bufwinnr(str2nr(nr))
    if selected_buffer_window != -1
      call <SID>move("down")
      if <SID>get_selected_buffer() == nr
        call <SID>move("up")
        if <SID>get_selected_buffer() == nr
          if bufexists(nr) && (!empty(getbufvar(nr, "&buftype")) || filereadable(bufname(nr)))
            call <SID>kill(0, 0)
            silent! exe selected_buffer_window . "wincmd w"
            enew
          else
            return
          endif
        else
          call <SID>load_buffer_into_window(selected_buffer_window)
        endif
      else
        call <SID>load_buffer_into_window(selected_buffer_window)
      endif
    else
      call <SID>kill(0, 0)
    endif

    let current_tab = tabpagenr()

    for t in range(1, tabpagenr('$'))
      if t == current_tab
        continue
      endif

      for b in tabpagebuflist(t)
        if b == nr
          silent! exe "tabn " . t

          let tab_window = bufwinnr(b)
          let controlspace_list    = gettabvar(t, "controlspace_list")

          call remove(controlspace_list, nr)

          silent! exe tab_window . "wincmd w"

          if !empty(controlspace_list)
            silent! exe "b" . keys(controlspace_list)[0]
          else
            enew
          endif
        endif
      endfor
    endfor

    silent! exe "tabn " . current_tab
    silent! exe "bdelete " . nr

    call <SID>forget_buffers_in_all_tabs([nr])
    call <SID>controlspace_toggle(1)
  endif
endfunction

function! <SID>forget_buffers_in_all_tabs(numbers)
  for t in range(1, tabpagenr("$"))
    let controlspace_list = gettabvar(t, "controlspace_list")

    for nr in a:numbers
      if exists("controlspace_list[" . nr . "]")
        call remove(controlspace_list, nr)
      endif
    endfor

    call settabvar(t, "controlspace_list", controlspace_list)
  endfor
endfunction

function! <SID>keep_buffers_for_keys(dict)
  let removed = []

  for b in range(1, bufnr('$'))
    if buflisted(b) && !has_key(a:dict, b) && !getbufvar(b, '&modified')
      " use wipeout for nonames
      let cmd = empty(getbufvar(b, "&buftype")) && !filereadable(bufname(b)) ? "bwipeout" : "bdelete"
      exe cmd b
      call add(removed, b)
    endif
  endfor

  return removed
endfunction

function! <SID>delete_hidden_noname_buffers(internal)
  let keep = {}

  " keep visible ones
  for t in range(1, tabpagenr('$'))
    for b in tabpagebuflist(t)
      let keep[b] = 1
    endfor
  endfor

  " keep all but nonames
  for b in range(1, bufnr("$"))
    if bufexists(b) && (!empty(getbufvar(b, "&buftype")) || filereadable(bufname(b)))
      let keep[b] = 1
    endif
  endfor

  if !a:internal
    call <SID>kill(0, 0)
  endif

  let removed = <SID>keep_buffers_for_keys(keep)

  if !empty(removed)
    call <SID>forget_buffers_in_all_tabs(removed)
  endif

  if !a:internal
    call <SID>controlspace_toggle(1)
  endif
endfunction

" deletes all foreign buffers
function! <SID>delete_foreign_buffers(internal)
  let buffers = {}
  for t in range(1, tabpagenr('$'))
    silent! call extend(buffers, gettabvar(t, 'controlspace_list'))
  endfor

  if !a:internal
    call <SID>kill(0, 0)
  endif

  call <SID>keep_buffers_for_keys(buffers)

  if !a:internal
    call <SID>controlspace_toggle(1)
  endif
endfunction

function! <SID>get_selected_buffer()
  let bufentry = b:buflist[line(".") - 1]
  return bufentry.number
endfunction

function! <SID>add_tab_buffer()
  if s:preview_mode
    return
  endif

  if !exists('t:controlspace_list')
    let t:controlspace_list = {}
  endif

  let current = bufnr('%')

  if !exists("t:controlspace_list[" . current . "]") &&
        \ getbufvar(current, '&modifiable') &&
        \ getbufvar(current, '&buflisted') &&
        \ current != bufnr("__CS__")
    let t:controlspace_list[current] = len(t:controlspace_list) + 1
  endif
endfunction

function! <SID>add_jump()
  if s:preview_mode
    return
  endif

  if !exists("t:controlspace_jumps")
    let t:controlspace_jumps = []
  endif

  let current = bufnr('%')

  if getbufvar(current, '&modifiable') && getbufvar(current, '&buflisted') && current != bufnr("__CS__")
    call add(s:controlspace_jumps, current)
    let s:controlspace_jumps = <SID>unique_list(s:controlspace_jumps)

    if len(s:controlspace_jumps) > g:controlspace_max_jumps + 1
      unlet s:controlspace_jumps[0]
    endif

    call add(t:controlspace_jumps, current)
    let t:controlspace_jumps = <SID>unique_list(t:controlspace_jumps)

    if len(t:controlspace_jumps) > g:controlspace_max_jumps + 1
      unlet t:controlspace_jumps[0]
    endif
  endif
endfunction

function! <SID>toggle_single_tab_mode()
  let s:single_tab_mode = !s:single_tab_mode

  if !empty(s:search_letters)
    let s:new_search_performed = 1
  endif

  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>toggle_order()
  if exists("t:sort_order")
    if t:sort_order == 1
      let t:sort_order = 2
    else
      let t:sort_order = 1
    endif

    call <SID>kill(0, 0)
    call <SID>controlspace_toggle(1)
  endif
endfunction

function! <SID>refresh_files()
  let s:files = []
  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>remove_file()
  let nr   = <SID>get_selected_buffer()
  let path = fnamemodify(s:file_mode ? s:files[nr - 1] : resolve(bufname(nr)), ":.")

  if empty(path) || !filereadable(path) || isdirectory(path)
    return
  endif

  if !<SID>confirmed("Remove file '" . path . "'?")
    return
  endif

  call <SID>delete_buffer()
  let s:files = []
  call delete(path)

  call <SID>kill(0, 0)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>move_file()
  let nr   = <SID>get_selected_buffer()
  let path = fnamemodify(s:file_mode ? s:files[nr - 1] : resolve(bufname(nr)), ":.")

  if !filereadable(path) || isdirectory(path)
    return
  endif

  let new_file = <SID>get_input("Move file to: ", path, "file")

  if empty(new_file)
    return
  endif

  let buffer_names = {}

  " must be collected BEFORE actual file renaming
  for b in range(1, bufnr('$'))
    let buffer_names[b] = fnamemodify(resolve(bufname(b)), ":.")
  endfor

  call rename(path, new_file)

  for [b, name] in items(buffer_names)
    if name == path
      let commands = ["f " . new_file, "w!"]
      call <SID>preview_buffer(str2nr(b), commands)
    endif
  endfor

  let s:files = []

  call <SID>kill(0, 1)
  call <SID>controlspace_toggle(1)
endfunction

function! <SID>explore_directory()
  let nr   = <SID>get_selected_buffer()
  let path = fnamemodify(s:file_mode ? s:files[nr - 1] : resolve(bufname(nr)), ":.:h")

  if !isdirectory(path)
    return
  endif

  call <SID>kill(0, 1)
  silent! exe "e " . path
endfunction!

function! <SID>edit_file()
  let nr   = <SID>get_selected_buffer()
  let path = fnamemodify(s:file_mode ? s:files[nr - 1] : resolve(bufname(nr)), ":.:h")

  if !isdirectory(path)
    return
  endif

  let new_file = <SID>get_input("Edit a new file: ", path . '/', "file")

  if empty(new_file) || isdirectory(new_file)
    return
  endif

  let s:files = []

  call <SID>kill(0, 1)
  silent! exe "e " . new_file
endfunction!

function! <SID>close_tab()
  if tabpagenr("$") == 1
    return
  endif

  if exists("t:controlspace_label") && !empty(t:controlspace_label)
    let buf_count = len(controlspace#bufferlist(tabpagenr()))

    if (buf_count > 1) && !<SID>confirmed("Close tab named '" . t:controlspace_label . "' with " . buf_count . " buffers?")
      return
    endif
  endif

  call <SID>kill(0, 1)

  tabclose

  call <SID>delete_hidden_noname_buffers(1)
  call <SID>delete_foreign_buffers(1)

  call <SID>controlspace_toggle(0)
endfunction

" Detach a buffer if it belongs to other tabs or delete it otherwise.
" It means, this function doesn't leave buffers without tabs.
function! <SID>close_buffer()
  let nr         = <SID>get_selected_buffer()
  let found_tabs = 0

  for t in range(1, tabpagenr('$'))
    let controlspace_list = gettabvar(t, 'controlspace_list')
    if !empty(controlspace_list) && exists("controlspace_list[" . nr . "]")
      let found_tabs += 1
    endif
  endfor

  if found_tabs > 1
    call <SID>detach_buffer()
  else
    call <SID>delete_buffer()
  endif
endfunction

function! <SID>detach_buffer()
  let nr = <SID>get_selected_buffer()

  if exists('t:controlspace_list[' . nr . ']')
    let selected_buffer_window = bufwinnr(nr)
    if selected_buffer_window != -1
      call <SID>move("down")
      if <SID>get_selected_buffer() == nr
        call <SID>move("up")
        if <SID>get_selected_buffer() == nr
          if bufexists(nr) && (!empty(getbufvar(nr, "&buftype")) || filereadable(bufname(nr)))
            call <SID>kill(0, 0)
            silent! exe selected_buffer_window . "wincmd w"
            enew
          else
            return
          endif
        else
          call <SID>load_buffer_into_window(selected_buffer_window)
        endif
      else
        call <SID>load_buffer_into_window(selected_buffer_window)
      endif
    else
      call <SID>kill(0, 0)
    endif
    call remove(t:controlspace_list, nr)
    call <SID>controlspace_toggle(1)
  endif

  return nr
endfunction

if !(has("ruby") && g:controlspace_use_ruby_bindings)
  finish
endif

let s:controlspace_folder = fnamemodify(resolve(expand('<sfile>:p')), ':h')

ruby << EOF
require "pathname"
require Pathname.new(VIM.evaluate("s:controlspace_folder")).parent.join("ruby", "controlspace").to_s
EOF
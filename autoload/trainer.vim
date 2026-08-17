" читаем клавиши по одной, сверяем с допустимыми ответами как с префиксом
function! s:read_combo(targets) abort
  let l:input = ''
  let l:live = copy(a:targets)
  while 1
    let l:c = getcharstr()
    if l:c ==# "\<Esc>"
      return ['abort', l:input]
    endif
    let l:input .= l:c
    if index(a:targets, l:input) >= 0
      return ['ok', l:input]
    endif
    call filter(l:live, {_, v -> stridx(v, l:input) == 0})
    if empty(l:live)
      return ['wrong', l:input]
    endif
  endwhile
endfunction

" общий каркас дрилла: скретч в сплите + q на выход, как в справке Vim
function! s:open_drill(start) abort
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  " буфер после верного ответа становится nomodifiable — без этого из него не выйти
  nnoremap <silent> <buffer> q :bwipeout!<CR>
  call setline(1, split(a:start, "\n"))
  call cursor(1, 1)
endfunction

" движок 1: проверка нажатой комбинации (для dw, x, dd, J, >> …)
function! trainer#challenge(desc, start, targets) abort
  call s:open_drill(a:start)
  redraw
  echo a:desc . '   (Esc to skip, q to close)'

  let [l:status, l:keys] = s:read_combo(a:targets)

  if l:status ==# 'ok'
    call feedkeys(l:keys, 'nx')          " проиграть комбинацию на буфере
    redraw
    echohl MoreMsg | echo 'Correct: ' . l:keys | echohl NONE
    return 1
  elseif l:status ==# 'abort'
    echo 'Skipped'
    return 0
  else
    echohl WarningMsg
    echo 'Wrong: ' . l:keys . '   (expected: ' . join(a:targets, ', ') . ')'
    echohl NONE
    return 0
  endif
endfunction

" движок 2: проверка результата (для ciw, f{c}, :s/… — где нажатия не ловятся)
function! trainer#goal(desc, start, goal, hint) abort
  call s:open_drill(a:start)
  let b:goal = a:goal
  " своя группа на каждый буфер: параллельные дриллы не гасят друг друга
  let b:trainer_group = 'TrainerGoal_' . bufnr('%')
  redraw
  echo a:desc . '   hint: ' . a:hint . '   (q to close)'

  execute 'augroup ' . b:trainer_group
      autocmd!
      execute 'autocmd TextChanged,TextChangedI <buffer> call s:check_goal(' . bufnr('%') . ')'
      " буфер закрыли, не решив — группа не должна оставаться висеть
      execute 'autocmd BufWipeout <buffer> call timer_start(0, {-> s:drop_group("' . b:trainer_group . '")})'
  augroup END
endfunction

function! s:check_goal(buf) abort
  if !exists('b:goal') | return | endif
  let l:lines = getline(1, '$')
  call map(l:lines, 'substitute(v:val, "\\s\\+$", "", "")')
  let l:text = join(l:lines, "\n")
  if l:text ==# b:goal
    let l:group = b:trainer_group
    execute 'autocmd! ' . l:group
    unlet b:goal
    " буфер нельзя править прямо из TextChanged — уходим в таймер,
    " и запоминаем номер буфера: за 50 мс пользователь может уйти в другой
    call timer_start(50, {-> s:announce(a:buf, l:group)})
  endif
endfunction

function! s:announce(buf, group) abort
  call s:drop_group(a:group)
  " буфер мог быть закрыт (bufhidden=wipe) за те 50 мс — тогда просто выходим
  if !bufexists(a:buf) | return | endif
  call setbufvar(a:buf, '&modifiable', 1)
  call setbufline(a:buf, 1, '✓ CORRECT — ' . get(getbufline(a:buf, 1), 0, ''))
  call setbufvar(a:buf, '&modifiable', 0)
  redraw
  echohl MoreMsg | echo 'Solved — press q to close' | echohl NONE
endfunction

" удаляем группу только вне её собственных автокоманд, иначе E936
function! s:drop_group(group) abort
  if !exists('#' . a:group) | return | endif
  execute 'autocmd! ' . a:group
  execute 'augroup! ' . a:group
endfunction

" номер скретча со шпаргалкой; ищем окно по нему, а не по имени файла:
" bufnr() со строкой матчит регэкспом, а не путём
let s:cheat_buf = -1

" открыть английскую шпаргалку в сплите
function! trainer#cheatsheet() abort
  " уже открыта — просто прыгнуть в её окно, не плодить сплиты
  if s:cheat_buf != -1 && bufexists(s:cheat_buf)
    let l:win = bufwinid(s:cheat_buf)
    if l:win != -1
      call win_gotoid(l:win)
    else
      execute 'vertical sbuffer ' . s:cheat_buf
    endif
    return
  endif

  if !filereadable(g:trainer_cheatsheet)
    echohl ErrorMsg
    echo 'Cheatsheet not found: ' . g:trainer_cheatsheet
    echohl NONE
    return
  endif

  " показываем копию в скретче, а не сам файл: иначе readonly/nomodifiable
  " останутся на буфере, когда шпаргалку откроют руками на правку
  vnew
  let s:cheat_buf = bufnr('%')
  call setline(1, readfile(g:trainer_cheatsheet))
  call cursor(1, 1)
  silent! file vim-trainer://cheatsheet
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal filetype=markdown          " подсветка вместо простыни текста
  setlocal nowrap                      " строки-команды не переносятся уродливо
  setlocal nomodifiable nomodified
  " q закрывает шпаргалку, как в справке Vim
  nnoremap <silent> <buffer> q :close<CR>
endfunction
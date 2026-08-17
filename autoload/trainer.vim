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

" движок 1: проверка нажатой комбинации (для dw, x, dd, J, >> …)
function! trainer#challenge(desc, start, targets) abort
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  call setline(1, split(a:start, "\n"))
  call cursor(1, 1)
  redraw
  echo a:desc . '   (Esc to skip)'

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
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  let b:goal = a:goal
  " своя группа на каждый буфер: параллельные дриллы не гасят друг друга
  let b:trainer_group = 'TrainerGoal_' . bufnr('%')
  call setline(1, split(a:start, "\n"))
  call cursor(1, 1)
  redraw
  echo a:desc . '   hint: ' . a:hint

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
  if !bufexists(a:buf) | return | endif
  call setbufvar(a:buf, '&modifiable', 1)
  call setbufline(a:buf, 1, '✓ CORRECT — ' . getbufoneline(a:buf, 1))
  call setbufvar(a:buf, '&modifiable', 0)
  call s:drop_group(a:group)
  redraw
endfunction

" удаляем группу только вне её собственных автокоманд, иначе E936
function! s:drop_group(group) abort
  if !exists('#' . a:group) | return | endif
  execute 'autocmd! ' . a:group
  execute 'augroup! ' . a:group
endfunction

" открыть английскую шпаргалку в сплите
function! trainer#cheatsheet() abort
  " если шпаргалка уже открыта — просто прыгнуть в её окно, не плодить сплиты
  let l:buf = bufnr(g:trainer_cheatsheet)
  if l:buf != -1 && bufwinnr(l:buf) != -1
    execute bufwinnr(l:buf) . 'wincmd w'
    return
  endif

  execute 'vsplit ' . fnameescape(g:trainer_cheatsheet)
  setlocal filetype=markdown          " подсветка вместо простыни текста
  setlocal readonly nomodifiable
  setlocal nowrap                      " строки-команды не переносятся уродливо
  " q закрывает шпаргалку, как в справке Vim
  nnoremap <silent> <buffer> q :close<CR>
endfunction
" ─── каталог ────────────────────────────────────────────────────────────────
" сами дриллы лежат в data/drills.json: добавить упражнение = дописать объект
" туда, трогать код не нужно
let s:drills = []
let s:last_id = ''
let s:seed = exists('*srand') ? srand() : []

function! s:fail(msg) abort
  echohl ErrorMsg | echomsg 'vim-trainer: ' . a:msg | echohl NONE
endfunction

" проверка одной записи: пустая строка — всё в порядке, иначе текст ошибки
function! s:validate(d, i) abort
  if type(a:d) != v:t_dict
    return 'entry ' . a:i . ' is not an object'
  endif
  for l:key in ['id', 'engine', 'desc', 'start']
    if type(get(a:d, l:key, 0)) != v:t_string || empty(a:d[l:key])
      return 'entry ' . a:i . ': missing "' . l:key . '"'
    endif
  endfor
  if a:d.engine ==# 'keys'
    if type(get(a:d, 'targets', 0)) != v:t_list || empty(a:d.targets)
      return a:d.id . ': engine "keys" needs a non-empty "targets" list'
    endif
  elseif a:d.engine ==# 'goal'
    if type(get(a:d, 'goal', 0)) != v:t_string
      return a:d.id . ': engine "goal" needs a "goal" string'
    endif
  else
    return a:d.id . ': unknown engine "' . a:d.engine . '"'
  endif
  return ''
endfunction

function! s:load() abort
  if !empty(s:drills) | return s:drills | endif
  if !filereadable(g:trainer_drills)
    call s:fail('drills file not found: ' . g:trainer_drills)
    return []
  endif
  try
    let l:data = json_decode(join(readfile(g:trainer_drills), "\n"))
  catch
    call s:fail('cannot parse ' . g:trainer_drills . ': ' . v:exception)
    return []
  endtry
  if type(l:data) != v:t_list
    call s:fail(g:trainer_drills . ': expected a list of drills')
    return []
  endif

  let l:seen = {}
  let l:i = 0
  for l:d in l:data
    let l:err = s:validate(l:d, l:i)
    " битая запись не должна ронять весь каталог — жалуемся и идём дальше
    if !empty(l:err)
      call s:fail(l:err)
    elseif has_key(l:seen, l:d.id)
      call s:fail('duplicate id "' . l:d.id . '"')
    else
      let l:seen[l:d.id] = 1
      call add(s:drills, l:d)
    endif
    let l:i += 1
  endfor
  return s:drills
endfunction

function! trainer#reload() abort
  let s:drills = []
  echo 'vim-trainer: ' . len(s:load()) . ' drills'
endfunction

function! s:rand(n) abort
  if a:n <= 1 | return 0 | endif
  if exists('*rand')
    return rand(s:seed) % a:n
  endif
  return str2nr(matchstr(reltimestr(reltime()), '\.\zs\d\+')) % a:n
endfunction

" аргумент — id, тег или пусто (весь каталог)
function! s:pool(arg) abort
  let l:all = s:load()
  if empty(a:arg) | return copy(l:all) | endif
  let l:byid = filter(copy(l:all), {_, d -> d.id ==# a:arg})
  if !empty(l:byid) | return l:byid | endif
  return filter(copy(l:all), {_, d -> index(get(d, 'tags', []), a:arg) >= 0})
endfunction

function! s:pick(pool) abort
  " не повторяем предыдущий дрилл, пока есть из чего выбирать
  let l:pool = len(a:pool) > 1
        \ ? filter(copy(a:pool), {_, d -> d.id !=# s:last_id})
        \ : a:pool
  return l:pool[s:rand(len(l:pool))]
endfunction

" :Trainer [id|tag]
function! trainer#run(...) abort
  let l:arg = a:0 ? trim(a:1) : ''
  let l:pool = s:pool(l:arg)
  if empty(l:pool)
    if !empty(s:drills)          " каталог цел, просто ничего не совпало
      call s:fail('no drill matching "' . l:arg . '"')
    endif
    return 0
  endif
  return trainer#start(s:pick(l:pool))
endfunction

" запустить конкретный дрилл (словарь из каталога)
function! trainer#start(drill) abort
  let s:last_id = a:drill.id
  if a:drill.engine ==# 'keys'
    return trainer#challenge(a:drill.desc, a:drill.start, a:drill.targets)
  endif
  return trainer#goal(a:drill.desc, a:drill.start, a:drill.goal, get(a:drill, 'hint', ''))
endfunction

function! trainer#complete(lead, cmdline, pos) abort
  let l:names = []
  for l:d in s:load()
    call add(l:names, l:d.id)
    call extend(l:names, get(l:d, 'tags', []))
  endfor
  return uniq(sort(filter(l:names, {_, v -> stridx(v, a:lead) == 0})))
endfunction

function! trainer#list() abort
  let l:drills = s:load()
  if empty(l:drills) | return | endif
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  nnoremap <silent> <buffer> q :bwipeout!<CR>
  let l:lines = ['" :Trainer {id|tag} to run one, q to close', '']
  for l:d in l:drills
    call add(l:lines, printf('%-20s %-5s %-38s %s',
          \ l:d.id, l:d.engine, l:d.desc, join(get(l:d, 'tags', []), ' ')))
  endfor
  call setline(1, l:lines)
  call cursor(3, 1)
  setlocal nowrap nomodifiable
endfunction

" ─── движки ─────────────────────────────────────────────────────────────────
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
  echo a:desc . (empty(a:hint) ? '' : '   hint: ' . a:hint) . '   (q to close)'

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
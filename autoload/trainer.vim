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
    if has_key(a:d, 'goal') && type(a:d.goal) != v:t_string
      return a:d.id . ': "goal" must be a string'
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

" аргумент — id, тег, «weak» или пусто (весь каталог)
function! s:pool(arg) abort
  let l:all = s:load()
  if empty(a:arg) | return copy(l:all) | endif
  if a:arg ==# 'weak'
    " нерешённые и те, где хоть раз ошиблись; если таких нет — весь каталог
    let l:weak = filter(copy(l:all), {_, d -> s:rate(d.id) < 1.0})
    return empty(l:weak) ? copy(l:all) : l:weak
  endif
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
  let s:pending_id = a:drill.id      " s:open_drill подхватит и заведёт счётчик
  if a:drill.engine ==# 'keys'
    " goal у keys-дрилла необязателен: обычно ожидаемый текст выводится из targets
    return trainer#challenge(a:drill.desc, a:drill.start, a:drill.targets,
          \ get(a:drill, 'goal', ''))
  endif
  return trainer#goal(a:drill.desc, a:drill.start, a:drill.goal, get(a:drill, 'hint', ''))
endfunction

function! trainer#complete(lead, cmdline, pos) abort
  let l:names = ['weak']
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

" ─── прогресс ───────────────────────────────────────────────────────────────
" s:progress держит статистику, s:active — открытые сейчас дриллы (по номеру
" буфера): результат записывается в момент закрытия буфера, поэтому контекст
" должен пережить сам буфер и не может лежать в b:
let s:progress = {}
let s:active = {}
let s:pending_id = ''
let s:session = {}

augroup TrainerDrill
  autocmd!
  autocmd VimLeavePre * call s:flush()
augroup END

" при выходе из Vim BufWipeout по буферам дриллов не приходит — досчитываем
" вручную, но сессию уже не двигаем: двигать некуда
function! s:flush() abort
  for l:ctx in values(s:active)
    call s:record(l:ctx.id, l:ctx.outcome)
  endfor
  let s:active = {}
endfunction

function! s:blank() abort
  return {'drills': {}, 'streak': 0, 'best': 0, 'total_ok': 0, 'total_try': 0}
endfunction

function! s:state() abort
  if !empty(s:progress) | return s:progress | endif
  let s:progress = s:blank()
  if !filereadable(g:trainer_state) | return s:progress | endif
  try
    let l:saved = json_decode(join(readfile(g:trainer_state), "\n"))
  catch
    call s:fail('cannot parse ' . g:trainer_state . ', starting fresh')
    return s:progress
  endtry
  if type(l:saved) != v:t_dict | return s:progress | endif
  " мержим по ключам: файл от прошлой версии не должен ломать новые поля
  for [l:k, l:v] in items(l:saved)
    if has_key(s:progress, l:k) && type(l:v) == type(s:progress[l:k])
      let s:progress[l:k] = l:v
    endif
  endfor
  return s:progress
endfunction

function! s:save() abort
  let l:dir = fnamemodify(g:trainer_state, ':h')
  try
    if !isdirectory(l:dir) | call mkdir(l:dir, 'p') | endif
    call writefile([json_encode(s:progress)], g:trainer_state)
  catch
    call s:fail('cannot write ' . g:trainer_state . ': ' . v:exception)
  endtry
endfunction

" доля решённого: -1 у дрилла, который ещё ни разу не пробовали
function! s:rate(id) abort
  let l:d = get(s:state().drills, a:id, {})
  if get(l:d, 'attempts', 0) == 0 | return -1.0 | endif
  return 1.0 * l:d.solved / l:d.attempts
endfunction

function! s:record(id, outcome) abort
  if empty(a:id) | return | endif        " дрилл запущен мимо каталога
  if a:outcome ==# 'skip' | return | endif  " Esc не должен портить статистику
  let l:st = s:state()
  let l:d = get(l:st.drills, a:id, {'attempts': 0, 'solved': 0, 'last': 0})
  let l:d.attempts += 1
  let l:st.total_try += 1
  if a:outcome ==# 'ok'
    let l:d.solved += 1
    let l:d.last = localtime()
    let l:st.total_ok += 1
    let l:st.streak += 1
    let l:st.best = max([l:st.best, l:st.streak])
  else
    let l:st.streak = 0
  endif
  let l:st.drills[a:id] = l:d
  call s:save()
endfunction

function! s:mark(buf, outcome) abort
  if has_key(s:active, a:buf)
    let s:active[a:buf].outcome = a:outcome
  endif
endfunction

" буфер дрилла закрыли — только здесь результат попадает в статистику
function! s:closed(buf) abort
  if !has_key(s:active, a:buf) | return | endif
  let l:ctx = remove(s:active, a:buf)
  call s:record(l:ctx.id, l:ctx.outcome)
  call s:tally(l:ctx.outcome)
endfunction

function! s:score_line() abort
  let l:st = s:state()
  return printf('%d/%d correct   streak %d (best %d)',
        \ l:st.total_ok, l:st.total_try, l:st.streak, l:st.best)
endfunction

" ─── сессия ─────────────────────────────────────────────────────────────────
" :TrainerSession [n] [id|tag|weak]
function! trainer#session(args) abort
  let l:count = 5
  let l:filter = ''
  for l:tok in split(a:args)
    if l:tok =~# '^\d\+$'
      let l:count = str2nr(l:tok)
    else
      let l:filter = l:tok
    endif
  endfor
  if l:count < 1
    call s:fail('session length must be at least 1')
    return
  endif
  if empty(s:pool(l:filter))
    if !empty(s:drills) | call s:fail('no drill matching "' . l:filter . '"') | endif
    return
  endif
  let s:session = {'left': l:count, 'total': l:count, 'ok': 0, 'filter': l:filter}
  call s:next()
endfunction

function! trainer#stop() abort
  let s:session = {}
  echo 'vim-trainer: session stopped'
endfunction

function! s:next() abort
  if empty(s:session) | return | endif
  let s:session.left -= 1
  call trainer#run(s:session.filter)
endfunction

function! s:tally(outcome) abort
  if empty(s:session)
    echo s:score_line()
    return
  endif
  if a:outcome ==# 'ok' | let s:session.ok += 1 | endif
  if s:session.left > 0
    echo printf('Session %d/%d — %d correct, next drill…',
          \ s:session.total - s:session.left, s:session.total, s:session.ok)
    " следующий дрилл нельзя открывать прямо из BufWipeout — уходим в таймер
    call timer_start(60, {-> s:next()})
  else
    let l:done = s:session
    let s:session = {}
    echohl MoreMsg
    echo printf('Session done: %d/%d correct   %s',
          \ l:done.ok, l:done.total, s:score_line())
    echohl NONE
  endif
endfunction

" ─── статистика ─────────────────────────────────────────────────────────────
function! s:ago(ts) abort
  if a:ts == 0 | return 'never' | endif
  let l:days = (localtime() - a:ts) / 86400
  return l:days == 0 ? 'today' : l:days . 'd ago'
endfunction

function! trainer#stats() abort
  let l:drills = s:load()
  if empty(l:drills) | return | endif
  let l:st = s:state()

  " слабые сверху: сперва нетронутые, потом с худшим процентом
  let l:rows = sort(copy(l:drills), {a, b -> s:rate(a.id) == s:rate(b.id)
        \ ? 0 : (s:rate(a.id) < s:rate(b.id) ? -1 : 1)})

  let l:pct = l:st.total_try > 0 ? (100 * l:st.total_ok) / l:st.total_try : 0
  let l:lines = [
        \ printf('vim-trainer — %d/%d correct (%d%%)   streak %d, best %d',
        \        l:st.total_ok, l:st.total_try, l:pct, l:st.streak, l:st.best),
        \ '" weakest first — :Trainer weak to drill them, q to close',
        \ '',
        \ printf('%-22s %8s %9s %6s   %s', 'id', 'solved', 'attempts', 'rate', 'last')]
  for l:d in l:rows
    let l:s = get(l:st.drills, l:d.id, {'attempts': 0, 'solved': 0, 'last': 0})
    let l:r = s:rate(l:d.id)
    call add(l:lines, printf('%-22s %8d %9d %6s   %s',
          \ l:d.id, l:s.solved, l:s.attempts,
          \ l:r < 0 ? '-' : float2nr(l:r * 100) . '%', s:ago(l:s.last)))
  endfor

  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  nnoremap <silent> <buffer> q :bwipeout!<CR>
  call setline(1, l:lines)
  call cursor(5, 1)
  setlocal nowrap nomodifiable
endfunction

function! trainer#reset(bang) abort
  if !a:bang && confirm('Erase vim-trainer progress?', "&Yes\n&No", 2) != 1
    return
  endif
  let s:progress = s:blank()
  call s:save()
  echo 'vim-trainer: progress reset'
endfunction

" ─── движки ─────────────────────────────────────────────────────────────────
function! s:strip(lines) abort
  return map(copy(a:lines), 'substitute(v:val, "\\s\\+$", "", "")')
endfunction

" прогон набранного с чистого листа: буфер откатывается к исходному тексту и
" вся последовательность проигрывается заново. так незавершённые команды
" (одинокое d) просто ничего не делают, а промежуточные состояния остаются
" честными — без этого пришлось бы гадать, что делать с висящим оператором
function! s:apply(start, keys) abort
  silent! keepjumps %delete _
  call setline(1, split(a:start, "\n"))
  call cursor(1, 1)
  " Esc в конце закрывает незавершённый ввод: cw…, висящий оператор, счётчик
  call feedkeys(a:keys . "\<Esc>", 'nx')
endfunction

" сравниваем сами: index() сверял бы строки с оглядкой на 'ignorecase'
function! s:matches(lines, wants) abort
  for l:want in a:wants
    if a:lines ==# l:want | return 1 | endif
  endfor
  return 0
endfunction

" эталонный результат: прогоняем один из targets и запоминаем, что вышло
function! s:derive(start, keys) abort
  call s:apply(a:start, a:keys)
  let l:want = s:strip(getline(1, '$'))
  call s:apply(a:start, '')
  return l:want
endfunction

" общий каркас дрилла: скретч в сплите + q на выход, как в справке Vim
function! s:open_drill(start) abort
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  " буфер после верного ответа становится nomodifiable — без этого из него не выйти
  nnoremap <silent> <buffer> q :bwipeout!<CR>
  call setline(1, split(a:start, "\n"))
  call cursor(1, 1)
  " по умолчанию дрилл считается пропущенным, пока движок не скажет иначе
  let s:active[bufnr('%')] = {'id': s:pending_id, 'outcome': 'skip'}
  let s:pending_id = ''
  execute 'autocmd TrainerDrill BufWipeout <buffer> call s:closed(' . bufnr('%') . ')'
endfunction

" движок 1: клавиши применяются к буферу, засчитывается результат (dw, D, J, >>)
" targets — эталонные ответы: по ним считается «пар» и берётся ожидаемый текст,
" но принимается любой способ, который приводит буфер к тому же виду
function! trainer#challenge(desc, start, targets, ...) abort
  call s:open_drill(a:start)
  let l:buf = bufnr('%')

  " эталонов может быть несколько: dw и de оба «удаляют слово», но оставляют
  " разный текст, и оба должны засчитываться
  let l:wants = a:0 && !empty(a:1)
        \ ? [s:strip(split(a:1, "\n"))]
        \ : map(copy(a:targets), 's:derive(a:start, v:val)')
  let l:par = min(map(copy(a:targets), 'strchars(v:val)'))
  let l:limit = max([l:par * 4, l:par + 6])   " защита от решения перебором
  let l:keys = ''

  while 1
    redraw
    echo a:desc . '   [' . l:keys . ']   (Esc to skip)'
    let l:c = getcharstr()
    " пусто приходит, когда ввода больше не будет (конец скрипта, закрытый
    " терминал) — без этого цикл крутился бы вхолостую
    if l:c ==# "\<Esc>" || empty(l:c)
      call s:mark(l:buf, 'skip')
      call s:apply(a:start, '')
      redraw
      echo 'Skipped   (expected: ' . join(a:targets, ', ') . ')   q to close'
      return 0
    endif
    let l:keys .= l:c
    " добираем всё, что человек успел настучать: иначе feedkeys ниже съест
    " остаток из typeahead и мы разойдёмся с тем, что реально в буфере.
    " счётчик — страховка от источника ввода, который никогда не пустеет
    let l:drain = 0
    while l:drain < 32
      let l:extra = getcharstr(0)
      if empty(l:extra) | break | endif
      let l:keys .= l:extra
      let l:drain += 1
    endwhile

    call s:apply(a:start, l:keys)

    if s:matches(s:strip(getline(1, '$')), l:wants)
      call s:mark(l:buf, 'ok')
      redraw
      let l:n = strchars(l:keys)
      let l:count = l:n == 1 ? '1 key' : l:n . ' keys'
      echohl MoreMsg
      echo l:n <= l:par
            \ ? printf('Correct: %s (%s)   q to close', l:keys, l:count)
            \ : printf('Correct: %s (%s, par %d: %s)   q to close',
            \          l:keys, l:count, l:par, join(a:targets, ', '))
      echohl NONE
      return 1
    endif

    if strchars(l:keys) >= l:limit
      call s:mark(l:buf, 'wrong')
      redraw
      echohl WarningMsg
      echo printf('Out of keys after %d   (expected: %s)   q to close',
            \ strchars(l:keys), join(a:targets, ', '))
      echohl NONE
      return 0
    endif
  endwhile
endfunction

function! trainer#hint() abort
  if !exists('b:trainer_hint') || empty(b:trainer_hint)
    echo 'No hint for this drill'
    return
  endif
  echohl MoreMsg | echo 'hint: ' . b:trainer_hint | echohl NONE
endfunction

" движок 2: проверка результата (для ciw, f{c}, :s/… — где нажатия не ловятся)
function! trainer#goal(desc, start, goal, hint) abort
  call s:open_drill(a:start)
  let b:goal = a:goal
  " подсказка не показывается сама: увидев «ciw», решать уже нечего
  let b:trainer_hint = a:hint
  " своя группа на каждый буфер: параллельные дриллы не гасят друг друга
  let b:trainer_group = 'TrainerGoal_' . bufnr('%')
  nnoremap <silent> <buffer> <F1> :TrainerHint<CR>
  redraw
  echo a:desc . (empty(a:hint) ? '   (q to close)' : '   (<F1> for a hint, q to close)')

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
    call s:mark(a:buf, 'ok')
    " буфер нельзя править прямо из TextChanged — уходим в таймер,
    " и запоминаем номер буфера: за 50 мс пользователь может уйти в другой
    call timer_start(50, {-> s:announce(a:buf, l:group)})
  endif
endfunction

function! s:announce(buf, group) abort
  call s:drop_group(a:group)
  " буфер мог быть закрыт (bufhidden=wipe) за те 50 мс — тогда просто выходим
  if !bufexists(a:buf) | return | endif
  " ciw/ci" оставляют в insert, а там q печатается буквой и буфер, который мы
  " сейчас залочим, на неё только ругнётся — выходим в normal за пользователя
  " ciw/ci" оставляют в insert, а там q печатается буквой в буфер, который мы
  " сейчас залочим. Esc кладём в очередь без 'x': с 'x' он выполняется прямо
  " здесь, вложенно, и до пользователя режим normal не доезжает
  if bufnr('%') == a:buf && mode() =~# '^[iR]'
    call feedkeys("\<Esc>", 'n')
  endif
  call setbufvar(a:buf, '&modifiable', 1)
  call setbufline(a:buf, 1, '✓ CORRECT — ' . get(getbufline(a:buf, 1), 0, ''))
  call setbufvar(a:buf, '&modifiable', 0)
  redraw
  " сообщение — следующим тиком: выход из insert перерисует командную строку
  " уже после нас и затрёт всё, что напечатано сейчас
  call timer_start(30, {-> s:solved_msg()})
endfunction

function! s:solved_msg() abort
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
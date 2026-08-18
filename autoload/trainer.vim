" ─── catalog ────────────────────────────────────────────────────────────────
" the drills themselves live in data/drills.json: adding an exercise means
" adding an object there, not touching this file
let s:drills = []
let s:last_id = ''
let s:seed = exists('*srand') ? srand() : []
" what a drill is judged by; "text" is the default, the rest need engine "keys"
let s:checks = ['text', 'cursor', 'register', 'mark', 'fold']

function! s:fail(msg) abort
  echohl ErrorMsg | echomsg 'vim-trainer: ' . a:msg | echohl NONE
endfunction

" checks one entry: empty string means it is fine, otherwise the error text
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

  let l:check = get(a:d, 'check', 'text')
  if index(s:checks, l:check) < 0
    return a:d.id . ': unknown check "' . string(l:check) . '"'
  endif
  if l:check !=# 'text'
    " watching state needs the replay of engine "keys": the goal engine would
    " fire the moment the cursor merely passes through the right spot
    if a:d.engine !=# 'keys'
      return a:d.id . ': check "' . l:check . '" needs engine "keys"'
    endif
    if index(['register', 'mark'], l:check) >= 0
          \ && strchars(get(a:d, 'check_arg', '')) != 1
      return a:d.id . ': check "' . l:check . '" needs a one-character "check_arg"'
    endif
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
    " one broken entry must not take down the catalog: complain and move on
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

" the argument is an id, a tag, "weak", or empty for the whole catalog
function! s:pool(arg) abort
  let l:all = s:load()
  if empty(a:arg) | return copy(l:all) | endif
  if a:arg ==# 'weak'
    " never solved, or missed at least once; if none, fall back to everything
    let l:weak = filter(copy(l:all), {_, d -> s:rate(d.id) < 1.0})
    return empty(l:weak) ? copy(l:all) : l:weak
  endif
  let l:byid = filter(copy(l:all), {_, d -> d.id ==# a:arg})
  if !empty(l:byid) | return l:byid | endif
  return filter(copy(l:all), {_, d -> index(get(d, 'tags', []), a:arg) >= 0})
endfunction

function! s:pick(pool) abort
  " never hand out the same drill twice in a row while there is a choice
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
    if !empty(s:drills)          " the catalog is fine, nothing just matched
      call s:fail('no drill matching "' . l:arg . '"')
    endif
    return 0
  endif
  return trainer#start(s:pick(l:pool))
endfunction

" run one specific drill, given as a dictionary from the catalog
function! trainer#start(drill) abort
  let s:last_id = a:drill.id
  let s:pending_id = a:drill.id      " s:open_drill picks this up and scores it
  if a:drill.engine ==# 'keys'
    " "goal" is optional here: the expected state is normally derived from targets
    return trainer#challenge(a:drill.desc, a:drill.start, a:drill.targets, {
          \ 'goal': get(a:drill, 'goal', ''),
          \ 'hint': get(a:drill, 'hint', ''),
          \ 'check': get(a:drill, 'check', 'text'),
          \ 'check_arg': get(a:drill, 'check_arg', '')})
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

" ─── progress ───────────────────────────────────────────────────────────────
" s:progress holds the statistics, s:active the drills open right now, keyed by
" buffer number: a result is recorded when the buffer closes, so its context has
" to outlive the buffer and cannot live in b:
let s:progress = {}
let s:active = {}
let s:pending_id = ''
let s:session = {}

augroup TrainerDrill
  autocmd!
  autocmd VimLeavePre * call s:flush()
augroup END

" quitting Vim delivers no BufWipeout for the drill buffers, so count them by
" hand; the session is not advanced, there is nowhere left to advance to
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
  " merge key by key: a file from another version must not break new fields
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

" solved ratio; -1 for a drill that has never been attempted
function! s:rate(id) abort
  let l:d = get(s:state().drills, a:id, {})
  if get(l:d, 'attempts', 0) == 0 | return -1.0 | endif
  return 1.0 * l:d.solved / l:d.attempts
endfunction

function! s:record(id, outcome) abort
  if empty(a:id) | return | endif         " drill started outside the catalog
  if a:outcome ==# 'skip' | return | endif  " Esc must not spoil the statistics
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

" the drill buffer is gone: the only place where a result reaches the stats
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

" ─── session ────────────────────────────────────────────────────────────────
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
    " a window cannot be opened from inside BufWipeout: hand it to a timer
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

" ─── statistics ─────────────────────────────────────────────────────────────
function! s:ago(ts) abort
  if a:ts == 0 | return 'never' | endif
  let l:days = (localtime() - a:ts) / 86400
  return l:days == 0 ? 'today' : l:days . 'd ago'
endfunction

function! trainer#stats() abort
  let l:drills = s:load()
  if empty(l:drills) | return | endif
  let l:st = s:state()

  " weakest first: never attempted, then whatever has the worst rate
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

" ─── engines ────────────────────────────────────────────────────────────────
function! s:strip(lines) abort
  return map(copy(a:lines), 'substitute(v:val, "\\s\\+$", "", "")')
endfunction

" replay what has been typed from scratch: the buffer is rolled back to the
" starting text and the whole sequence runs again. that way an unfinished
" command (a lone d) simply does nothing and the intermediate states stay
" honest — otherwise a pending operator would be anyone's guess
function! s:apply(start, keys, ...) abort
  " a:1 is the register a "register" drill works with: it lives outside the
  " buffer, so rolling the text back is not enough to undo the previous replay
  if a:0 && !empty(a:1) | call setreg(a:1, []) | endif
  silent! keepjumps %delete _
  call setline(1, split(a:start, "\n"))
  call cursor(1, 1)
  " the trailing Esc closes whatever is unfinished: cw…, a pending operator, a count
  call feedkeys(a:keys . "\<Esc>", 'nx')
endfunction

" what the drill is judged by. everything here has to survive a replay from the
" starting text, which is why windows and buffers are not on the list: switching
" one would send the next replay into somebody else's buffer
function! s:snapshot(check, arg) abort
  if a:check ==# 'cursor'
    return [line('.'), col('.')]
  elseif a:check ==# 'register'
    return [getreg(a:arg), getregtype(a:arg)]
  elseif a:check ==# 'mark'
    return getpos("'" . a:arg)[1:2]
  elseif a:check ==# 'fold'
    return map(range(1, line('$')), 'foldclosed(v:val)')
  endif
  return s:strip(getline(1, '$'))
endfunction

" compare by hand: index() would match strings with an eye on 'ignorecase'
function! s:matches(lines, wants) abort
  for l:want in a:wants
    if a:lines ==# l:want | return 1 | endif
  endfor
  return 0
endfunction

" check_arg names a register for one kind of check and a mark for another; only
" the register has to be wiped between replays, and only that one may be touched
function! s:reg_of(check, arg) abort
  return a:check ==# 'register' ? a:arg : ''
endfunction

" reference state: replay one of the targets and keep whatever came out
function! s:derive(start, keys, check, arg) abort
  call s:apply(a:start, a:keys, s:reg_of(a:check, a:arg))
  let l:want = s:snapshot(a:check, a:arg)
  call s:apply(a:start, '', s:reg_of(a:check, a:arg))
  return l:want
endfunction

" shared frame for every drill: a scratch split plus q to close, as in Vim help
function! s:open_drill(start) abort
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  " after a correct answer the buffer turns nomodifiable — without this mapping
  " there is no way out of it
  nnoremap <silent> <buffer> q :bwipeout!<CR>
  " every drill buffer answers <F1>, otherwise it falls through to Vim's help
  let b:trainer_hint = ''
  nnoremap <silent> <buffer> <F1> :TrainerHint<CR>
  call setline(1, split(a:start, "\n"))
  call cursor(1, 1)
  " a drill counts as skipped until an engine says otherwise
  let s:active[bufnr('%')] = {'id': s:pending_id, 'outcome': 'skip'}
  let s:pending_id = ''
  execute 'autocmd TrainerDrill BufWipeout <buffer> call s:closed(' . bufnr('%') . ')'
endfunction

" engine 1: keys are applied to the buffer and the outcome is what counts
" (dw, D, J, >>). targets are the reference answers: they set par and provide
" the expected state, but any route to the same state is accepted.
" the optional fourth argument is either a goal string (kept for older callers)
" or {'goal': …, 'check': …, 'check_arg': …}
function! trainer#challenge(desc, start, targets, ...) abort
  let l:opt = a:0 ? (type(a:1) == v:t_dict ? a:1 : {'goal': a:1}) : {}
  let l:goal = get(l:opt, 'goal', '')
  let l:check = get(l:opt, 'check', 'text')
  let l:arg = get(l:opt, 'check_arg', '')
  let l:reg = s:reg_of(l:check, l:arg)

  call s:open_drill(a:start)
  let l:buf = bufnr('%')
  let l:hint = get(l:opt, 'hint', '')
  let b:trainer_hint = l:hint            " for <F1> once the drill is over
  let l:show_hint = 0
  if l:check ==# 'fold' | setlocal foldmethod=manual foldlevel=0 | endif
  " registers are global, so a drill borrows one and gives it back
  let l:saved = l:check ==# 'register' ? [getreg(l:arg), getregtype(l:arg)] : []

  " there can be several reference states: dw and de both "delete a word" but
  " leave different text behind, and both have to count
  let l:wants = !empty(l:goal)
        \ ? [s:strip(split(l:goal, "\n"))]
        \ : map(copy(a:targets), {_, k -> s:derive(a:start, k, l:check, l:arg)})
  " a reference answer that changes nothing leaves the expected state equal to
  " the starting one, and the drill would be "solved" by the first keystroke.
  " that is a broken catalog entry, so say so instead of pretending to teach
  call s:apply(a:start, '', l:reg)
  let l:initial = s:snapshot(l:check, l:arg)
  if s:matches(l:initial, l:wants)
    call s:mark(l:buf, 'skip')
    call s:fail(a:desc . ': a reference answer changes nothing, check "targets"')
    echo 'Broken drill   q to close'
    return 0
  endif

  let l:par = min(map(copy(a:targets), 'strchars(v:val)'))
  let l:limit = max([l:par * 4, l:par + 6])   " no grinding the answer out
  let l:keys = ''

  try
  while 1
    redraw
    echo a:desc . '   [' . l:keys . ']'
          \ . (l:show_hint ? '   hint: ' . l:hint : '')
          \ . (empty(l:hint) || l:show_hint ? '' : '   (<F1> for a hint)')
          \ . '   (Esc to skip)'
    let l:c = getcharstr()
    " getcharstr() bypasses mappings, so <F1> is handled here — and it must not
    " count as a keystroke against par
    if l:c ==# "\<F1>"
      let l:show_hint = 1
      continue
    endif
    " an empty string means no more input is coming (end of a script, closed
    " terminal) — without this the loop would spin on nothing
    if l:c ==# "\<Esc>" || empty(l:c)
      call s:mark(l:buf, 'skip')
      call s:apply(a:start, '', l:reg)
      redraw
      echo 'Skipped   (expected: ' . join(a:targets, ', ') . ')   q to close'
      return 0
    endif
    let l:keys .= l:c
    " pick up everything already typed ahead: otherwise the feedkeys below eats
    " the rest of the typeahead and we drift apart from the actual buffer.
    " the counter guards against an input source that never runs dry
    let l:drain = 0
    while l:drain < 32
      let l:extra = getcharstr(0)
      if empty(l:extra) | break | endif
      let l:keys .= l:extra
      let l:drain += 1
    endwhile

    call s:apply(a:start, l:keys, l:reg)

    if s:matches(s:snapshot(l:check, l:arg), l:wants)
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
  finally
    if !empty(l:saved) | call setreg(l:arg, l:saved[0], l:saved[1]) | endif
  endtry
endfunction

function! trainer#hint() abort
  if !exists('b:trainer_hint') || empty(b:trainer_hint)
    echo 'No hint for this drill'
    return
  endif
  echohl MoreMsg | echo 'hint: ' . b:trainer_hint | echohl NONE
endfunction

" engine 2: checks the result, for ciw, f{c}, :s/… — where keys cannot be caught
function! trainer#goal(desc, start, goal, hint) abort
  call s:open_drill(a:start)
  let b:goal = a:goal
  " the hint stays hidden: once "ciw" is on screen there is nothing left to solve
  let b:trainer_hint = a:hint
  " one augroup per buffer, so parallel drills do not cancel each other
  let b:trainer_group = 'TrainerGoal_' . bufnr('%')
  nnoremap <silent> <buffer> <F1> :TrainerHint<CR>
  redraw
  echo a:desc . (empty(a:hint) ? '   (q to close)' : '   (<F1> for a hint, q to close)')

  execute 'augroup ' . b:trainer_group
      autocmd!
      execute 'autocmd TextChanged,TextChangedI <buffer> call s:check_goal(' . bufnr('%') . ')'
      " closed without solving: the group must not be left hanging around
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
    " the buffer cannot be edited from inside TextChanged, so use a timer, and
    " remember the buffer number: 50ms is enough to walk off into another one
    call timer_start(50, {-> s:announce(a:buf, l:group)})
  endif
endfunction

function! s:announce(buf, group) abort
  call s:drop_group(a:group)
  " the buffer may already be gone (bufhidden=wipe) after those 50ms
  if !bufexists(a:buf) | return | endif
  " ciw/ci" leave you in Insert mode, where q is typed as a letter into the
  " buffer we are about to lock. queue the Esc without 'x': with 'x' it runs
  " nested, right here, and Normal mode never reaches the user
  if bufnr('%') == a:buf && mode() =~# '^[iR]'
    call feedkeys("\<Esc>", 'n')
  endif
  call setbufvar(a:buf, '&modifiable', 1)
  call setbufline(a:buf, 1, '✓ CORRECT — ' . get(getbufline(a:buf, 1), 0, ''))
  call setbufvar(a:buf, '&modifiable', 0)
  redraw
  " the message goes out on the next tick: leaving Insert redraws the command
  " line after us and would wipe anything printed now
  call timer_start(30, {-> s:solved_msg()})
endfunction

function! s:solved_msg() abort
  echohl MoreMsg | echo 'Solved — press q to close' | echohl NONE
endfunction

" delete the group only outside its own autocommands, otherwise E936
function! s:drop_group(group) abort
  if !exists('#' . a:group) | return | endif
  execute 'autocmd! ' . a:group
  execute 'augroup! ' . a:group
endfunction

" buffer number of the cheatsheet scratch; the window is looked up by it rather
" than by file name, because bufnr() matches a string as a regexp, not a path
let s:cheat_buf = -1

" open the cheatsheet in a split
function! trainer#cheatsheet() abort
  " already open: jump to its window instead of piling up more splits
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

  " show a copy in a scratch buffer rather than the file itself: otherwise
  " readonly/nomodifiable stick to it when the cheatsheet is opened for editing
  vnew
  let s:cheat_buf = bufnr('%')
  call setline(1, readfile(g:trainer_cheatsheet))
  call cursor(1, 1)
  silent! file vim-trainer://cheatsheet
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal filetype=markdown          " highlighting instead of a wall of text
  setlocal nowrap                      " command lines must not wrap raggedly
  setlocal nomodifiable nomodified
  " q closes the cheatsheet, as in Vim's own help
  nnoremap <silent> <buffer> q :close<CR>
endfunction

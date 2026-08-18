" Checks that apply to every drill in the shipped catalog, so a new entry is
" covered without touching the tests.
source <sfile>:p:h:h/helper.vim

let s:drills = json_decode(join(readfile(g:test_root . '/data/drills.json'), "\n"))
call assert_true(len(s:drills) > 0, 'the catalog is not empty')

" keys a drill can never be solved with: <Esc> skips, and anything that moves
" focus would send the replay into another buffer
for s:d in s:drills
  if get(s:d, 'engine', '') !=# 'keys' | continue | endif
  for s:t in s:d.targets
    call assert_notequal('', s:t, s:d.id . ': empty target')
    call assert_true(stridx(s:t, "\<Esc>") < 0, s:d.id . ': <Esc> skips a keys drill')
    call assert_true(stridx(s:t, "\<C-w>") < 0, s:d.id . ': CTRL-W would break the replay')
    call assert_true(s:t !~# '^:\(b\|bn\|bp\|e \)', s:d.id . ': switching buffers breaks the replay')
  endfor
  " par is what the shortest target costs, so an answer of length 0 is nonsense
  call assert_true(min(map(copy(s:d.targets), 'strchars(v:val)')) > 0, s:d.id . ': par is zero')
endfor

" every goal drill has to start unsolved and be solvable by its own goal
call UseState()
let s:goals = filter(copy(s:drills), 'get(v:val, "engine", "") ==# "goal"')
for s:d in s:goals
  call assert_notequal(s:d.start, s:d.goal, s:d.id . ': already solved at the start')
  execute 'Trainer ' . s:d.id
  call assert_equal(split(s:d.start, "\n"), getline(1, '$'), s:d.id . ': opens on its own text')
  call assert_equal(s:d.goal, b:goal, s:d.id . ': carries its own goal')
  call SolveGoal()
  call assert_equal('✓ CORRECT — ' . split(s:d.goal, "\n")[0], getline(1),
        \ s:d.id . ': is recognised as solved')
  call CloseDrill()
endfor
call assert_equal(len(s:goals), get(ReadState(), 'total_ok', -1),
      \ 'every goal drill was scored')

call Finish('shipped_drills')

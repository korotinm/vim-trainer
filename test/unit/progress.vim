source <sfile>:p:h:h/helper.vim

" the goal engine is the one that can be driven without a terminal, so the
" scoring rules are checked through it
call UseState()
enew
call setline(1, 'work buffer')
let s:home = bufnr('%')

Trainer change-word
call SolveGoal()
call assert_equal(0, get(ReadState(), 'total_ok', -1),
      \ 'a solved drill is not scored until its buffer closes')
call CloseDrill()

let s:st = ReadState()
call assert_equal(1, s:st.total_ok, 'a solved drill counts')
call assert_equal(1, s:st.total_try, 'and counts as one attempt')
call assert_equal(1, s:st.streak, 'streak starts')
call assert_equal(1, s:st.best, 'best follows the streak')
call assert_equal(1, s:st.drills['change-word'].solved, 'per-drill record')
call assert_true(s:st.drills['change-word'].last > 0, 'timestamp is set')

" closing a drill without solving must not spoil anything
Trainer delete-in-quotes
call CloseDrill()
let s:st = ReadState()
call assert_equal(1, s:st.total_try, 'a skip is not an attempt')
call assert_equal(1, s:st.streak, 'a skip does not break the streak')
call assert_equal(1, len(s:st.drills), 'a skip leaves no record')

" a second solve extends the streak
Trainer delete-in-quotes
call SolveGoal()
call CloseDrill()
let s:st = ReadState()
call assert_equal([2, 2, 2, 2],
      \ [s:st.total_ok, s:st.total_try, s:st.streak, s:st.best], 'streak grows')

call assert_equal(s:home, bufnr('%'), 'we are back in the buffer we started from')
call assert_equal('work buffer', getline(1), 'and it is untouched')

" "weak" leaves out what is already solved every time
call StubEngines()
let g:started = []
for s:i in range(40) | call trainer#run('weak') | endfor
call assert_equal(-1, index(g:started, 'Change "brown" to "red"'),
      \ 'a drill at 100% is not weak')
call assert_true(len(uniq(sort(copy(g:started)))) > 1, 'weak still offers a choice')

" state survives a reload and is thrown away on reset
call assert_equal(2, ReadState().total_ok, 'state is on disk')
call trainer#reset(1)
let s:st = ReadState()
call assert_equal([0, 0, 0], [s:st.total_ok, s:st.total_try, s:st.streak], 'reset clears the totals')
call assert_equal({}, s:st.drills, 'reset clears the per-drill records')

" a corrupt state file is reported and replaced, not fatal
let g:trainer_state = tempname()
call writefile(['{ not json'], g:trainer_state)
silent! call trainer#stats()
call assert_true(line('$') > 3, 'stats still opens on a broken state file')
call feedkeys('q', 'xt')

call Finish('progress')

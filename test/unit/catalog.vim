source <sfile>:p:h:h/helper.vim

" the catalog that ships with the plugin has to load whole
let s:ids = filter(trainer#complete('', '', 0), 'v:val !=# "weak"')
call assert_true(len(s:ids) >= 12, 'shipped catalog loads: ' . len(s:ids) . ' names')
call assert_notequal(-1, index(s:ids, 'delete-word'), 'known drill is there')
call assert_notequal(-1, index(trainer#complete('', '', 0), 'weak'), '"weak" is completed')
call assert_equal(['delete-in-quotes', 'delete-to-eol', 'delete-word'],
      \ trainer#complete('de', '', 0), 'completion filters by prefix')

" a broken entry is dropped, the rest of the file still loads
call UseDrills([
      \ {'id': 'good', 'engine': 'keys', 'desc': 'd', 'start': 's', 'targets': ['x']},
      \ {'id': 'no-engine', 'desc': 'd', 'start': 's'},
      \ {'id': 'bad-engine', 'engine': 'nope', 'desc': 'd', 'start': 's'},
      \ {'id': 'no-targets', 'engine': 'keys', 'desc': 'd', 'start': 's'},
      \ {'id': 'no-goal', 'engine': 'goal', 'desc': 'd', 'start': 's'},
      \ {'id': 'good', 'engine': 'keys', 'desc': 'dup', 'start': 's', 'targets': ['y']}])
call assert_equal(['good', 'weak'], trainer#complete('', '', 0),
      \ 'only the valid entry survives, duplicates refused')

" checks are validated too, and only the keys engine may use them
call UseDrills([
      \ {'id': 'cursor-ok', 'engine': 'keys', 'desc': 'd', 'start': 's',
      \  'targets': ['x'], 'check': 'cursor'},
      \ {'id': 'unknown-check', 'engine': 'keys', 'desc': 'd', 'start': 's',
      \  'targets': ['x'], 'check': 'nope'},
      \ {'id': 'check-on-goal', 'engine': 'goal', 'desc': 'd', 'start': 's',
      \  'goal': 'g', 'check': 'cursor'},
      \ {'id': 'reg-no-arg', 'engine': 'keys', 'desc': 'd', 'start': 's',
      \  'targets': ['x'], 'check': 'register'},
      \ {'id': 'mark-long-arg', 'engine': 'keys', 'desc': 'd', 'start': 's',
      \  'targets': ['x'], 'check': 'mark', 'check_arg': 'ab'}])
call assert_equal(['cursor-ok', 'weak'], trainer#complete('', '', 0),
      \ 'bad checks are rejected')

" a missing or unparsable file is reported, not fatal
let g:trainer_drills = '/nope/missing.json'
silent! call trainer#reload()
call assert_equal(['weak'], trainer#complete('', '', 0), 'missing file leaves an empty catalog')
let g:trainer_drills = tempname()
call writefile(['{ not json'], g:trainer_drills)
silent! call trainer#reload()
call assert_equal(['weak'], trainer#complete('', '', 0), 'broken json leaves an empty catalog')

" pool selection: by id, by tag, by "weak", and nothing at all
call UseDrills([
      \ {'id': 'a', 'engine': 'keys', 'desc': 'A', 'start': 's', 'targets': ['x'], 'tags': ['one']},
      \ {'id': 'b', 'engine': 'keys', 'desc': 'B', 'start': 's', 'targets': ['x'], 'tags': ['one', 'two']},
      \ {'id': 'c', 'engine': 'keys', 'desc': 'C', 'start': 's', 'targets': ['x'], 'tags': ['two']}])
call UseState()
call StubEngines()

let g:started = []
call trainer#run('a')
call assert_equal(['A'], g:started, 'id picks exactly one drill')

let g:started = []
for s:i in range(30) | call trainer#run('two') | endfor
call assert_equal(['B', 'C'], uniq(sort(copy(g:started))), 'tag restricts the pool')

let g:started = []
call trainer#run('nope')
call assert_equal([], g:started, 'unknown argument runs nothing')

" a random run never repeats the previous drill and covers the catalog
let g:started = []
for s:i in range(60) | call trainer#run('') | endfor
let s:repeats = 0
for s:i in range(1, len(g:started) - 1)
  if g:started[s:i] ==# g:started[s:i - 1] | let s:repeats += 1 | endif
endfor
call assert_equal(0, s:repeats, 'no drill twice in a row')
call assert_equal(['A', 'B', 'C'], uniq(sort(copy(g:started))), 'every drill shows up')

call Finish('catalog')

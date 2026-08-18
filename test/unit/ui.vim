source <sfile>:p:h:h/helper.vim

" every documented command and autoload function exists
for s:cmd in ['Trainer', 'TrainerSession', 'TrainerHint', 'TrainerStop',
      \ 'TrainerStats', 'TrainerList', 'TrainerReload', 'TrainerCheat',
      \ 'TrainerResetStats']
  call assert_true(exists(':' . s:cmd) == 2, s:cmd . ' is defined')
endfor
call trainer#complete('', '', 0)     " force the autoload file to load
for s:fn in ['trainer#run', 'trainer#session', 'trainer#start', 'trainer#stop',
      \ 'trainer#challenge', 'trainer#goal', 'trainer#hint', 'trainer#stats',
      \ 'trainer#list', 'trainer#reload', 'trainer#reset', 'trainer#complete',
      \ 'trainer#cheatsheet']
  call assert_true(exists('*' . s:fn), s:fn . '() is defined')
endfor

" the plugin binds no real keys, only <Plug> names
let s:taken = filter(split(execute('nmap'), "\n"),
      \ 'v:val =~# "Trainer" && v:val !~# "<Plug>"')
call assert_equal([], s:taken, 'no key is taken by default')
for s:plug in ['<Plug>(TrainerRun)', '<Plug>(TrainerWeak)', '<Plug>(TrainerSession)',
      \ '<Plug>(TrainerStats)', '<Plug>(TrainerList)', '<Plug>(TrainerCheat)']
  call assert_notequal('', maparg(s:plug, 'n'), s:plug . ' is defined')
endfor

" the help file is installed and its tags resolve
silent! execute 'helptags ' . g:test_root . '/doc'
let s:missing = []
for s:tag in ['vim-trainer', 'trainer-drills', 'trainer-checks', 'trainer-tags',
      \ 'trainer-progress', 'trainer-par', ':TrainerSession', 'g:trainer_state']
  try
    execute 'help ' . s:tag
  catch
    call add(s:missing, s:tag)
  endtry
endfor
call assert_equal([], s:missing, 'every help tag resolves')
silent! helpclose


" a missing cheatsheet is reported instead of opening an empty split
let g:trainer_cheatsheet = '/nope/missing.md'
enew
let s:windows = winnr('$')
silent! call trainer#cheatsheet()
call assert_equal(s:windows, winnr('$'), 'no window is opened for a missing file')
let g:trainer_cheatsheet = g:test_root . '/data/cheatsheet_en.md'

" the cheatsheet opens as a scratch copy and reuses its buffer
enew
call setline(1, 'work buffer')
let s:home = bufnr('%')
call trainer#cheatsheet()
let s:cheat = bufnr('%')
call assert_equal(2, winnr('$'), 'the cheatsheet opened in a split')
call assert_equal('markdown', &filetype, 'it is highlighted')
call assert_equal('nofile', &buftype, 'it is a scratch copy, not the file')
call assert_equal(0, &modifiable, 'and it is read-only')
call assert_true(line('$') > 100, 'the whole cheatsheet is there')

call win_gotoid(bufwinid(s:home))
call trainer#cheatsheet()
call assert_equal(2, winnr('$'), 'calling it again does not pile up splits')
call assert_equal(s:cheat, bufnr('%'), 'it jumps to the existing window')
call feedkeys('q', 'xt')
call trainer#cheatsheet()
call assert_equal(s:cheat, bufnr('%'), 'reopening reuses the same buffer')
call feedkeys('q', 'xt')

" the shipped file itself keeps its options when opened by hand
" edit! — the buffer we came from is modified and must be abandoned, otherwise
" E37 leaves us looking at the wrong buffer
execute 'edit! ' . fnameescape(g:trainer_cheatsheet)
call assert_equal('cheatsheet_en.md', fnamemodify(bufname('%'), ':t'),
      \ 'we really are in the cheatsheet file')
call assert_equal(1, &modifiable, 'the real file is not locked')
call assert_equal(0, &readonly, 'nor read-only')
call assert_equal('', &buftype, 'nor turned into a scratch buffer')


" :TrainerList shows every drill
TrainerList
call assert_true(line('$') >= 12, ':TrainerList lists the catalog')
call assert_equal(0, &modifiable, 'the list is read-only')
call feedkeys('q', 'xt')

call Finish('ui')

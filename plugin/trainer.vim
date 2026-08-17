if exists('g:loaded_trainer') | finish | endif
let g:loaded_trainer = 1

let s:root = expand('<sfile>:p:h:h')

" all three paths can be overridden: your own drill catalog, your own
" cheatsheet, your own place for the progress file
if !exists('g:trainer_cheatsheet')
  let g:trainer_cheatsheet = s:root . '/data/cheatsheet_en.md'
endif
if !exists('g:trainer_drills')
  let g:trainer_drills = s:root . '/data/drills.json'
endif
if !exists('g:trainer_state')
  let s:state_dir = empty($XDG_STATE_HOME) ? expand('~/.local/state') : $XDG_STATE_HOME
  let g:trainer_state = s:state_dir . '/vim-trainer/progress.json'
endif

" :Trainer                 — a random drill
" :Trainer delete-word     — one specific drill, by id
" :Trainer text-objects    — a random drill carrying that tag
" :Trainer weak            — a random one among those you keep missing
" -bar: without it everything after | leaks into the command argument
command! -bar -nargs=? -complete=customlist,trainer#complete Trainer
      \ call trainer#run(<q-args>)
" :TrainerSession [n] [id|tag|weak] — n drills in a row with a score, 5 by default
command! -bar -nargs=* -complete=customlist,trainer#complete TrainerSession
      \ call trainer#session(<q-args>)
command! -bar TrainerHint   call trainer#hint()
command! -bar TrainerStop   call trainer#stop()
command! -bar TrainerStats  call trainer#stats()
command! -bar TrainerList   call trainer#list()
command! -bar TrainerReload call trainer#reload()
command! -bar TrainerCheat  call trainer#cheatsheet()
command! -bar -bang TrainerResetStats call trainer#reset(<bang>0)

" the plugin takes no keys: <leader> is the user's own space. these names cannot
" be typed, they exist so there is something to bind to:
"   nmap <leader>d <Plug>(TrainerRun)
nnoremap <silent> <Plug>(TrainerRun)     :Trainer<CR>
nnoremap <silent> <Plug>(TrainerWeak)    :Trainer weak<CR>
nnoremap <silent> <Plug>(TrainerSession) :TrainerSession<CR>
nnoremap <silent> <Plug>(TrainerStats)   :TrainerStats<CR>
nnoremap <silent> <Plug>(TrainerList)    :TrainerList<CR>
nnoremap <silent> <Plug>(TrainerCheat)   :TrainerCheat<CR>

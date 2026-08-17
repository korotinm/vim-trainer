# Vim Keymap — shortcut reference

All commands are for **Normal mode** unless marked otherwise: `(ins)` — insert mode, `(vis)` — visual mode.

Notation: `{m}` — motion, `{c}` — character, `{n}` — count.

## Vim grammar

Formula: **[count] operator [count] object**

An operator (`d` `c` `y` `>` `=` `gu` `gU` …) combines with a motion or a text object — you compose commands instead of memorizing them:

- `d2w` — delete 2 words
- `y3j` — yank 3 lines downward
- `ci(` — change everything inside the parentheses
- `gUiw` — uppercase the word under the cursor
- `5dd` — delete 5 lines
- `>ap` — indent the paragraph

## Modes

- `i` / `a` — insert before / after the cursor
- `I` / `A` — insert at start / end of line
- `o` / `O` — open a new line below / above
- `v` / `V` — visual mode: characters / lines
- `Ctrl-v` — visual block (columns)
- `R` — replace mode
- `gi` — insert at the last edit position
- `:` — command line (Ex)
- `Esc` / `Ctrl-[` — back to Normal

## Motions

- `h` `j` `k` `l` — left / down / up / right
- `w` / `b` — next / previous word (`W` `B` — whitespace-delimited)
- `e` / `ge` — end of word / end of previous word
- `0` / `^` / `$` — start of line / first non-blank / end of line
- `gg` / `G` — start / end of file
- `{n}G` — go to line n
- `f{c}` / `F{c}` — to character `c` forward / backward
- `t{c}` / `T{c}` — till character `c` forward / backward
- `;` / `,` — repeat `f`/`t` forward / backward
- `%` — jump to the matching `(` `)` `[` `]` `{` `}`
- `{` / `}` — previous / next paragraph
- `(` / `)` — previous / next sentence
- `H` `M` `L` — top / middle / bottom of screen
- `Ctrl-d` / `Ctrl-u` — half a screen down / up
- `Ctrl-f` / `Ctrl-b` — a full screen down / up
- `zz` `zt` `zb` — current line to center / top / bottom of screen
- `Ctrl-o` / `Ctrl-i` — back / forward in the jump list
- `g;` / `g,` — back / forward in the change list

## Editing

- `x` / `X` — delete character under / before the cursor
- `r{c}` — replace character with `c`
- `s` / `S` — substitute character / line (→ insert)
- `d{m}` `dd` `D` — delete: motion / line / to end of line
- `c{m}` `cc` `C` — change (delete and enter insert)
- `y{m}` `yy` — yank motion / line
- `p` / `P` — put after / before the cursor
- `u` / `Ctrl-r` — undo / redo
- `.` — repeat the last change
- `J` / `gJ` — join lines with / without a space
- `>>` `<<` `==` — indent / unindent / auto-indent
- `~` — toggle case of the character
- `guiw` / `gUiw` — word to lowercase / UPPERCASE
- `Ctrl-a` / `Ctrl-x` — increment / decrement the number under the cursor
- `Ctrl-w` `Ctrl-u` (ins) — delete previous word / to start of line
- `Ctrl-o` (ins) — run one Normal-mode command without leaving insert

## Text objects

`i` — inner (contents only), `a` — around (including delimiters).

- `iw` / `aw` — word / word plus surrounding whitespace
- `i"` `i'` `` i` `` — inside quotes (`a"` — including them)
- `i(` `i[` `i{` `i<` — inside brackets (`a(` — including them)
- `it` / `at` — inside an HTML/XML tag / including the tag
- `ip` / `ap` — paragraph
- `is` / `as` — sentence

Examples: `ci"` · `di(` · `yap` · `vit` · `dap`

## Visual mode

- `o` — move to the other end of the selection
- `gv` — restore the previous selection
- `d` `y` `c` — delete / yank / change
- `>` `<` `=` — indent / unindent / auto-indent
- `Ctrl-v` → `I` / `A` — insert on every line of the block
- `u` `U` `~` — lowercase / uppercase / toggle case
- `J` — join the selected lines

## Search and replace

- `/text` / `?text` — search forward / backward
- `n` / `N` — next / previous match
- `*` / `#` — search the word under the cursor forward / backward
- `:%s/old/new/g` — replace throughout the file
- `:%s/old/new/gc` — same, confirming each replacement
- `:s/…` — replace on the current line
- `:'<,'>s/…` — replace within the selection
- `:noh` — clear search highlighting
- `:g/pat/d` — delete lines matching `pat` (`:v` — all lines not matching)

## Registers

- `"{a-z}y` / `"{a-z}p` — yank / put via a named register
- `"+y` / `"+p` — system clipboard
- `"0p` — the last yank (deletes don't overwrite it)
- `"_d` — delete without touching any register (black hole)
- `:reg` — show register contents
- `Ctrl-r {reg}` (ins) — insert a register in insert or command-line mode

## Macros

- `qa` … `q` — record a macro into register `a`
- `@a` / `@@` — run / repeat the last one
- `10@a` — run it 10 times
- `:'<,'>norm @a` — run it on every line of the selection

## Marks

- `ma` / `mA` — mark within the file / global mark (across files)
- `` `a `` / `'a` — jump to mark: exact position / start of line
- ``` `` ``` — position before the last jump
- `` `. `` — position of the last change
- `:marks` — list marks

## Buffers, windows, tabs

- `:e file` — open a file
- `:w` `:q` `:wq` `:q!` — write / quit / both / quit without saving
- `:ls` / `:b {n}` — list buffers / switch to a buffer
- `:bn` `:bp` `:bd` — next / previous / delete buffer
- `Ctrl-^` — previous (alternate) buffer
- `:sp` / `:vsp` — horizontal / vertical split
- `Ctrl-w` `h` `j` `k` `l` — move between windows
- `Ctrl-w w` — cycle to the next window
- `Ctrl-w q` / `Ctrl-w o` — close this window / close all others
- `Ctrl-w =` — equalize window sizes
- `Ctrl-w` `+` `-` `<` `>` — adjust height / width
- `:tabnew` / `:tabc` — new tab / close tab
- `gt` / `gT` — next / previous tab

## Folding

- `za` — toggle fold
- `zo` / `zc` — open / close fold
- `zR` / `zM` — open all / close all
- `zj` / `zk` — move to next / previous fold

## Miscellaneous

- `ZZ` / `ZQ` — save and quit / quit without saving
- `:!cmd` — run a shell command
- `:r !cmd` / `:r file` — read command output / file contents into the buffer
- `gd` — go to definition (within the file)
- `gf` — open the file under the cursor
- `K` — look up documentation for the word under the cursor
- `ga` — show the character code under the cursor
- `Ctrl-g` — show file name and position
- `:earlier 5m` — roll the file back 5 minutes (`:later` — forward)
- `:set nu rnu` — relative line numbers
- `q:` / `q/` — command-line / search history window
- `:h {topic}` — help: `:h quickref`, `:h index`

To practice, run `vimtutor` in a terminal. Full documentation: [vimhelp.org](https://vimhelp.org)
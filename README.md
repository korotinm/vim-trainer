# vim-trainer

The commands you keep looking up, until you stop looking them up.

Small drills inside your own Vim: a task, a scratch buffer, and a check. Solve
it any way you like — the plugin looks at the result, not at the keys you
happened to press — and it remembers how you are doing.

![Demo](media/demo.gif)

## Install

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'korotinm/vim-trainer'
```

As a native package:

```bash
git clone https://github.com/korotinm/vim-trainer ~/.vim/pack/plugins/start/vim-trainer
vim -u NONE -c 'helptags ~/.vim/pack/plugins/start/vim-trainer/doc' -c q
```

## Use

```vim
:Trainer               " one random drill
:TrainerSession 10     " ten in a row, with a score at the end
:Trainer weak          " the ones you keep missing
:TrainerStats          " how you are doing
```

Inside a drill: solve the task, then press `q` to close it. `<F1>` shows a
hint, `<Esc>` skips.

Any route to the right result counts. `dW` and `4x` solve a "delete the word"
drill just as well as `dw` — and if there was a shorter way, the plugin says so:

```
Correct: daw (3 keys, par 2: dw, daw, de)
```

No keys are bound by default. `:help vim-trainer` has the rest.

## Add your own drill

A drill is a JSON object in [`data/drills.json`](data/drills.json). No
Vimscript, no build step:

```json
{
  "id": "uppercase-word",
  "engine": "goal",
  "desc": "Uppercase the word under the cursor",
  "start": "make this loud",
  "goal": "make THIS loud",
  "hint": "gUiw",
  "tags": ["operators", "text-objects"]
}
```

Then `:TrainerReload` and `:Trainer uppercase-word` to try it out. If it works,
open a merge request with that one file changed — **it is the most useful thing
you can send**, and the CI checks the drill for you.

Good drills come from your own misses: the command you look up every time, the
text object you never reach for. `:TrainerStats` shows which ones those are.

<details>
<summary><b>All the fields</b></summary>

| field | |
|---|---|
| `id` | unique name; it keys the progress file, so renaming it loses that history |
| `engine` | `keys` or `goal`, see below |
| `desc` | the task, shown above the drill |
| `start` | the starting text; `\n` makes it several lines |
| `targets` | keys engine: the reference answers |
| `goal` | goal engine: the expected text |
| `hint` | optional, shown only on `<F1>` |
| `check` | what to compare: `text` (default), `cursor`, `register`, `mark`, `fold` |
| `check_arg` | the register or mark `check` looks at |
| `tags` | one or two, from the list below |

`targets` is not a whitelist. Each answer is replayed on the starting text when
the drill opens, and anything you type that reaches the same result counts. The
shortest one sets par. List several answers only when they lead to genuinely
different but equally correct results — `dw` and `de` differ by a leading space,
so both are listed.

A broken entry is reported and skipped; the rest of the catalog still loads.

</details>

<details>
<summary><b>Tags</b></summary>

One or two per drill. The first says what kind of move it is, the second
narrows the construct: `ciw` is `operators` + `text-objects`. The right-hand
column is the `check` such a drill needs.

| tag | what it covers | check |
|---|---|---|
| `operators` | `d` `c` `y` `>` `=` `gu` `gU` with a motion or a text object | text |
| `text-objects` | `iw` `aw` `i(` `a"` `ip` `it` | text |
| `editing` | single edits: `x` `r` `J` `>>` `~` `.` `u` `Ctrl-r` | text |
| `modes` | `i` `a` `I` `A` `o` `O` `gi` `R` | text |
| `visual` | `v` `V` `Ctrl-v` plus an edit on the selection | text |
| `replace` | `:s///`, `:g`, `&` | text |
| `macros` | `q` `@`, when the macro edits | text |
| `motions` | `w` `b` `e` `f{c}` `t{c}` `{` `}` `gg` `G` | `cursor` |
| `search` | `/` `?` `n` `N` `*` `#` | `cursor` |
| `marks` | `m{a}`, `` `a ``, `'a` | `mark` |
| `registers` | `"ay` `"ap` `:let @a` | `register` |
| `folds` | `zf` `zo` `zc` `za` | `fold` |

Add a new tag only once three drills would carry it; below that it is just a
longer name for the `id`. Window and buffer switching has no tag on purpose —
see the next section for why.

</details>

<details>
<summary><b>How answers are judged</b></summary>

Two engines, because not every command can be watched the same way:

- **`keys`** — your keystrokes are read one by one and the whole sequence is
  replayed on the buffer after each one, so you see the effect as you type and
  the plugin can count keystrokes. For commands that stay in Normal mode: `dw`,
  `D`, `J`, `>>`.
- **`goal`** — you edit the buffer freely and the result is compared once you
  stop. For everything whose keystrokes cannot be captured, because you end up
  in Insert mode or on the command line: `ciw`, `di"`, `:s/…`.

`par` is the shortest listed answer. Solving a drill the long way still counts;
after `par * 4` keystrokes the drill gives up and records a miss, so it cannot
be ground out one `x` at a time.

Usually the thing being compared is the buffer text. `check` points it at
something else — the cursor, a register, a mark, the folds — which is how
motions and searches get drills at all. Any `check` other than `text` needs the
keys engine: the goal engine watches events and would fire the moment the
cursor merely passed through the right spot.

Registers are global, so a drill wipes the one it borrows between attempts and
hands it back untouched afterwards.

Windows and buffers have no drills: the replay starts from the drill buffer
after every keystroke, so a key that moves focus would rewrite somebody else's
buffer.

</details>

<details>
<summary><b>Every command, and mappings</b></summary>

| command | |
|---|---|
| `:Trainer` | random drill |
| `:Trainer delete-word` | one specific drill, by id |
| `:Trainer text-objects` | random drill with that tag |
| `:Trainer weak` | random drill among those you keep missing |
| `:TrainerSession [n] [id\|tag\|weak]` | `n` drills in a row (default 5) with a score |
| `:TrainerHint` | reveal the hint (`<F1>` inside a drill; it costs no keystrokes) |
| `:TrainerStop` | abandon the session |
| `:TrainerStats` | totals, streak, per-drill table, weakest first |
| `:TrainerResetStats[!]` | erase progress |
| `:TrainerList` | show the catalog |
| `:TrainerReload` | re-read the drills file after editing it |
| `:TrainerCheat` | keymap cheatsheet in a split |

The plugin binds no keys. If you want some, hang them on the `<Plug>` names —
note `nmap`, not `nnoremap`:

```vim
nmap <leader>d <Plug>(TrainerRun)
nmap <leader>w <Plug>(TrainerWeak)
nmap <leader>s <Plug>(TrainerSession)
```

Also available: `<Plug>(TrainerStats)`, `<Plug>(TrainerList)`,
`<Plug>(TrainerCheat)`.

</details>

<details>
<summary><b>Where the score is kept</b></summary>

```
vim-trainer — 11/14 correct (78%)   streak 2, best 5

id                       solved  attempts   rate   last
delete-in-quotes              1         5    20%   3d ago
change-word                   2         3    66%   today
delete-word                   4         4   100%   today
```

Results go to `$XDG_STATE_HOME/vim-trainer/progress.json` (`~/.local/state/…`
when that variable is empty) as each drill closes:

```json
{"drills": {"delete-word": {"attempts": 3, "solved": 2, "last": 1786982867}},
 "streak": 2, "best": 5, "total_ok": 11, "total_try": 14}
```

A correct answer extends the streak, a wrong one resets it, and a skip counts
for nothing at all — pressing `<Esc>` should not spoil your statistics.

</details>

<details>
<summary><b>Configuration</b></summary>

```vim
let g:trainer_drills     = expand('~/dotfiles/my-drills.json')
let g:trainer_cheatsheet = expand('~/dotfiles/vim-keys.txt')
let g:trainer_state      = expand('~/dotfiles/vim-trainer.json')
```

Set them in your vimrc, before the plugin loads. `:help vim-trainer` documents
the rest, including the autoload API.

</details>

<details>
<summary><b>Tests</b></summary>

```bash
./test/run.sh          # everything
./test/run.sh unit     # no terminal needed
./test/run.sh pty      # drives Vim through a pseudo terminal
```

`test/unit/` uses Vim's own `assert_*` functions and needs nothing installed.
`test/pty/` exists because the keys engine reads keys from a real tty: those
suites run Vim under `script(1)` and read what it painted on the screen. Set
`VIM_BIN` to test another binary.

The suite loads the shipped catalog and solves every drill in it, so a broken
exercise fails the build.

</details>

## Requirements

Vim 8.2.4419 or newer — that is where `getcharstr()` landed, and the keys
engine needs it. Also `+timers` and `json_decode()`, which any current build
has.

## License

MIT — see [LICENSE](LICENSE).

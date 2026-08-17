# vim-trainer

Drills for Vim keys, with scoring. A drill opens in a scratch split, you solve
it, the plugin checks the answer and keeps score across sessions.

![Demo](media/demo.gif)

## Two engines

Both judge the text you end up with, never the keys you happened to press —
`dW` and `4x` solve a `dw` drill just as well as `dw`. They differ in how they
watch you:

- **`keys`** — keystrokes are read with `getcharstr()` and the whole sequence is
  replayed on the buffer after every key, so the effect is visible as you type
  and keystrokes can be counted. For commands that stay in Normal mode: `dw`,
  `D`, `J`, `>>`. `<Esc>` skips.
- **`goal`** — you edit the buffer freely and the result is compared once you
  stop. For everything whose keystrokes cannot be captured, because you end up
  in Insert mode or on the command line: `ciw`, `di"`, `:s/…`.

A keys drill also grades economy: `par` is the shortest listed answer, and
solving it the long way still counts but says so.

```
Correct: daw (3 keys, par 2: dw, daw, de)
```

Grinding the answer out one `x` at a time will not work — after `par * 4`
keystrokes the drill gives up and records a miss.

Every drill opens in a split; `q` closes it, and that is also what advances a
session.

## Install

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'korotinm/vim-trainer'
```

As a native package:

```bash
git clone <repo> ~/.vim/pack/plugins/start/vim-trainer
vim -u NONE -c 'helptags ~/.vim/pack/plugins/start/vim-trainer/doc' -c q
```

## Usage

| Command | |
|---|---|
| `:Trainer` | random drill |
| `:Trainer delete-word` | one specific drill, by id |
| `:Trainer text-objects` | random drill with that tag |
| `:Trainer weak` | random drill among those you keep missing |
| `:TrainerSession [n] [id\|tag\|weak]` | `n` drills in a row (default 5) with a score |
| `:TrainerHint` | reveal the hint of the current goal drill (`<F1>` inside it) |
| `:TrainerStop` | abandon the session |
| `:TrainerStats` | totals, streak, per-drill table, weakest first |
| `:TrainerResetStats[!]` | erase progress |
| `:TrainerList` | show the catalog |
| `:TrainerReload` | re-read the drills file after editing it |
| `:TrainerCheat` | keymap cheatsheet in a split |

No keys are taken by default. If you want some, hang them on the `<Plug>` names
yourself — note `nmap`, not `nnoremap`:

```vim
nmap <leader>d <Plug>(TrainerRun)
nmap <leader>w <Plug>(TrainerWeak)
nmap <leader>s <Plug>(TrainerSession)
```

Also available: `<Plug>(TrainerStats)`, `<Plug>(TrainerList)`,
`<Plug>(TrainerCheat)`.

```
vim-trainer — 11/14 correct (78%)   streak 2, best 5

id                       solved  attempts   rate   last
delete-in-quotes              1         5    20%   3d ago
change-word                   2         3    66%   today
delete-word                   4         4   100%   today
```

## Adding drills — and sending them back

**This is the easiest thing to contribute, and the most useful.** A drill is a
JSON object, not code: if you keep forgetting a command, add it to
[`data/drills.json`](data/drills.json) and open a merge request. No Vimscript
involved, no build step, nothing to learn beyond the fields below.

The file is a plain list of objects:

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

`engine` is `keys` (needs `targets`) or `goal` (needs `goal`, the expected
text; `hint` is optional). `tags` feed `:Trainer {tag}`. A broken entry is
reported and skipped, the rest still load; run `:TrainerReload` to pick up
edits.

`targets` is not a whitelist: each answer is replayed on the starting text when
the drill opens, and anything you type that reaches one of those results counts.
List several only when they lead to genuinely different but equally correct
text — `dw` and `de` differ by a leading space, so both are listed. The shortest
one sets par. A `goal` on a keys drill overrides the derived results.

### Tags

Both engines judge the buffer text, so **a drill has to end in a text
difference** — anything that only moves the cursor, sets a mark, folds a
region or switches window cannot be checked and does not belong here. That is
why the vocabulary is short. Use these tags, one or two per drill:

| tag | what it covers |
|---|---|
| `operators` | `d` `c` `y` `>` `=` `gu` `gU` with a motion or a text object |
| `text-objects` | `iw` `aw` `i(` `a"` `ip` `it` |
| `editing` | single edits: `x` `r` `J` `>>` `~` `.` `u` `Ctrl-r` |
| `modes` | `i` `a` `I` `A` `o` `O` `gi` `R` — the insert itself is the change |
| `visual` | `v` `V` `Ctrl-v` **plus** an edit on the selection |
| `replace` | `:s///`, `:g`, `&` |
| `macros` | `q` `@`, when the macro edits |
| `registers` | `"ay` and `"ap` — the drill has to end in a put |

The first tag says what kind of move it is, the second narrows the construct:
`ciw` is `operators` + `text-objects`. Add a new tag only once three drills
would carry it; below that it is just a longer name for the `id`.

### Sending a drill upstream

1. Add your object to [`data/drills.json`](data/drills.json), with a unique
   `id` and a `tags` list that matches the existing ones.
2. `:TrainerReload`, then `:Trainer <your-id>` — solve it once, and for a keys
   drill try a second route to the same text to check `targets` is honest.
3. Open a merge request with just that file changed.

Good drills come from your own misses: the command you look up every time, the
text object you never reach for. `:TrainerStats` shows which ones those are.

## Progress

Results are written to `$XDG_STATE_HOME/vim-trainer/progress.json`
(`~/.local/state/…` when that variable is empty) as a drill buffer is closed:

```json
{"drills": {"delete-word": {"attempts": 3, "solved": 2, "last": 1786982867}},
 "streak": 2, "best": 5, "total_ok": 11, "total_try": 14}
```

A correct answer extends the streak, a wrong one resets it, and a skip counts
for nothing at all — pressing `<Esc>` should not spoil your statistics.

## Configuration

```vim
let g:trainer_drills     = expand('~/dotfiles/my-drills.json')
let g:trainer_cheatsheet = expand('~/dotfiles/vim-keys.md')
let g:trainer_state      = expand('~/dotfiles/vim-trainer.json')
```

Set them in your vimrc, before the plugin loads. `:help vim-trainer` documents
the rest, including the autoload API.

## Requirements

Vim 8.2+ with `+timers` and `json_decode()`; the keys engine needs
`getcharstr()`. Neovim is untested.

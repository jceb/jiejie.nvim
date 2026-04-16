# jiejie

Neovim plugin that adds support for the Jujutsu source control management
system. The design is heavily inspired by
[vim-fugitive](https://github.com/tpope/vim-fugitive).

![jiejie](./jiejie.png)

## Usage

jiejie provides a large amount of key mappings in the status log window to
expose as much of jujutsu's functionality as possible. For remembering the
mappings more easily, these rules might prove helpful:

- The current change (`@`) is at the center of all interactions. Rebasing a
  commit, squashing changes, all references the current change.
- When the cursor is on another change, this other change becomes the target of
  the operation, e.g. the current change (`@`) is rebased upon the change under
  the cursor.
- Breaking operations, e.g. moving a bookmark backwards (`--allow-backwards`) or
  modifying an immutable change (`--ignore-immutable`), can be achieved by
  adding a leading `!` to the mapping.
- Destructive operations or operations that prompt the user for an arbitrary
  change id use upper case letters, e.g. `cbM` for moving an arbitrary bookmark
  to the change under the cursor.
- Shortcuts follow jujutsu's aliases where possible, e.g. all bookmark related
  `cb` mappings start with `c` (change) and `b` (bookmark alias).

## Features

### UX very close to [tpope's vim-fugitive](https://github.com/tpope/vim-fugitive)

- Edit file (`<CR>`, `o`, `gO`, `O`)
- Edit file at a certain revision (`:Jedit [revision]:[file]`, or by selecting
  the file in the status log window via `<CR>`, `o`, `gO`, `O`)
- Open full change in preview window (`K`)
- Toggle inline diff (`=`)
- Compare multiple versions of a file (`d?`, `:Jdiffsplit [revision]`, `dD`,
  `dd`, `dV`, `dv`, `dS`, `ds`, `dH`, `dh`, `dq`)
- Wraper for `jj` CLI (`:J` or `:Jj`)
- Show help (`g?`, `c?`, `d?`, `r?`, `s?`)

### Status log buffer (`:J`, `:Jj`, `Jj log`)

- Includes the list of modified files alongside the status log
- Adjust view of displayed log entries (`s?`, `sA`, `sa`, `sB`,`sb`, `sd`, `sf`,
  `sr`, `sq`, `ss`, `1ss`, `..ss`, `sT`, `st`)
- Navigation between changes, files and hunks (`[[`, `]]`, `<Tab>`)
- Increase or decrease the number of log entries shown (`<C-a>`, `<C-x>`)
- Close status log buffer (`q`, `gq`)
- Reload status log (`R`)
- Populate a `:` or `:!` command with the file under the cursor (`.`, `!!`)

#### Modify commits from the status log buffer

- Add `!` prefix to mappings when modifying immutable changes
- Edit change (`<CR>`)
- Pull and push changes to git (`gu`, `gp`)
- Modify change description in an editor window (`ce`) or quick edit the first
  line (`cd`)
- Copy change description of change / commit ID (`yy`, `yc`, `yC`)
- Create a new change (`c?`, `A`, `a`, `cA`, `ca`, `cI`, `ci`, `i`, `I`, `cn`)
- Create a merge commit (`cB`, `cm`, `cM`)
- Commit change or file under the cursor (`cc`)
- Squash change or file into parent or into the change under the cursor (`cs`,
  `cS`)
- Duplicate / cherry-pick change under the cursor (`cpP`, `cpp`, `cpM`, `cpm`,
  `cpT`, `cpt`)
- Revert change under the cursor (`cR`)
- Abandon change or file under the cursor (`X`)
- Rebase branch, tree or individual change (`r?`, `<<`, `>>`, `rbD`, `rbd`,
  `rbH`, `rbh`, `rbM`, `rbm`, `rbO`, `rbo`, `rbt`, `rD`, `rd`, `rO`, `ro`, `rR`,
  `rr`, `rtD`, `rtd`, `rtO`, `rto`, `rtt` `rtT`)
- Undo / redo last operation (`u`, `<C-r>`)
- Bookmark management (`cba`, `cbb`, `cbc`, `cbF`, `cbf`, `cbM`, `cbm`, `cbR`,
  `cbr`, `cbt`, `cbX`, `cbx`)
- Tag management (`ctc`, `ctm`, `ctt`, `ctX`, `ctx`)
- Untrack and track files (`x`, `!x`)
- Focus / open operation log (`so`, `sO`)
- Focus / open evolog (`se`, `sE`)

### Operation log buffer (`:J oplog`, `:Jj oplog`)

- Focus / open status log buffer (`so`, `sO`)
- Restore repository at operation (`<CR>`)
- Close operation log buffer (`q`)
- Reload operation log (`R`)
- Increase or decrease the number of log entries shown (`<C-a>`, `<C-x>`)

### Evolog buffer (`:J evolog`, `:Jj evolog`)

- Focus / open status log buffer (`se`, `sE`)
- Edit change (`<CR>`)
- Close operation log buffer (`q`)
- Reload operation log (`R`)
- Open full change in preview window (`K`)
- Increase or decrease the number of log entries shown (`<C-a>`, `<C-x>`)

## Installation

With Lazy, add this configuration to nvim:

```lua
{
  -- https://github.com/jceb/jiejie.nvim.git
  "jceb/jiejie.nvim",
}
```

## Roadmap

See [ROADMAP.md](./ROADMAP.md).

## Limitations

- Changing the commit log and operation log
  [node icon style](https://docs.jj-vcs.dev/latest/config/#node-style) will
  break the plugin!

## References

There isn't too much information about Jujutus on the web, yet. Here are a
number of references that I find helpful:

- [Jujutsu documentation](https://docs.jj-vcs.dev/latest/)
- [Jujutsu's Wiki - Neovim integration](https://github.com/jj-vcs/jj/wiki/Vim,-Neovim)
- [Jujutsu Tutorial by Steve Klabnik](https://steveklabnik.github.io/jujutsu-tutorial/)
- Jujutsu introductions:
  - Git Merge 2024
    [intro](https://www.youtube.com/watch?app=desktop&v=LV0JzI8IcCY) by Martin
    von Zweigbergk
  - GitButler's [intro](https://www.youtube.com/watch?app=desktop&v=dwyMlLYIrPk)
    and [advanced](https://www.youtube.com/watch?v=PsiXflgIC8Q) videos
  - And [more](https://github.com/jj-vcs/jj/wiki/Media)

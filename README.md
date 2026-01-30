# jiejie

Neovim plugin that adds support for the Jujutsu source control management
system. The design is heavily inspired by
[fugitive.vim](https://github.com/tpope/vim-fugitive).

![jiejie](./jiejie.png)

## Features

- UX very close to [tope's fugitive](https://github.com/tpope/vim-fugitive)
  - Toggle inline diff (`=`)
  - Jump to file (`<CR>`, `o`, `gO`, `O`)
  - Edit old revisions of a file (`:Jedit [revision]:[file]`)
  - Wraper for `jj` CLI (`:J` or `:Jj`)
- Log buffer (`:J` or `:Jj`)
  - Includes the list of modified files alongside the log
  - Navigation between changes, files and hunks (`[[`, `]]`, `i`)
  - Increase or decrease the number of log entries shown (`<C-a>`, `<C-x>`)
- Modify changes from the log buffer
  - Add `!` prefix to mappings for modification of immutable changes
  - Edit change (`<CR>`)
  - Pull and push changes to git (`gp`, `gP`)
  - Modify change description in editor (`de`) or quick edit first line (`dd`)
  - Create a new change after the change under the cursor (`cn`)
  - Commit change or file under the cursor (`cc`)
  - Squash change or file under the cursor (`cs`, `cS`)
  - Duplicate change under the cursor (`cd`)
  - Revert change under the cursor (`crc`)
  - Abandon change or file under the cursor (`X`)
  - Rebase change tree or individual change (`rr`, `ro`)
  - Revert last operation (`cU`)
  - Bookmark management (`cbc`, `cbX`, `cbx`, `cbF`, `cbf`, `cbm`, `cbr`)
  - Tag management (`ctc`, `ctm`, `ctX`, `ctx`)

## Installation

With Lazy, add this configuration to nvim:

```lua
{
  -- https://github.com/jceb/jiejie.nvim.git
  "jceb/jiejie.nvim",
}
```

## Roadmap

- [x] Basic feature: Display log in window
- [x] Basic feature: Make J / Jj a simple wrapper for jj CLI
- [x] Commands: describe
- [x] Commands: edit
- [x] Commands: squash
- [x] Commands: commit
- [x] Commands: new
- [x] Log: Display changed files in log view
- [x] Log: Jump to file from log window
- [x] Commands: abandon / restore
- [x] Commands: revert
- [x] Log: Increase / decrease the number of displayed revisions
- [x] Commands: git push & pull
- [x] Basic feature: Display file changes as diff inside the log window
- [x] Commands: op revert (undo) last operation
- [x] Commands: Jedit
- [x] Configuration: expose all key bindings as <Plug>
- [x] Commands: provide convenience mappings for editing the current file in a
      new split (o) or tab (O)
- [x] Commands: squash and commit for individual files
- [x] Navigation: movement mappings for commits, files and hunks
- [x] Commands: rebase
- [x] Commands: bookmark
- [x] Commands: tag
- [x] Commands: duplicate

Priority 1

- [ ] New Feature: Detect all files/buffers in a jj repository and trigger log
      reloads when they change
- [ ] Log: support toggling between different log views
- [ ] Commands: diff

Priority 2

- [ ] Commands: keep diff expansion when reloading the log
- [ ] Configuration: make mappings configurable
- [ ] Commands: support visual mode for squash, commit, split and restore key
      bindings
- [ ] Commands: worktree

Priority 3

- [ ] API: extract commands from buffer.lua and put them in commands.lua
- [ ] Commands: Jedit for commits and directories
- [ ] Commands: split (current workaround: commit one file instead of the whole
      change, then squash the other files that should be part of the commit)
- [ ] Docs: make screen recordings of jiejie's usage
- [ ] Key: display full summary of a change via K
- [ ] Refactor: follow lua's style of returning errors
- [ ] Key: pressing X on a hunk should restore it
- [ ] Commands: blame
- [ ] Commands: absorb
- [ ] Commands: diffedit
- [ ] Commands: show full change
- [ ] Commands: undo / redo
- [ ] Commands: parallelize
- [ ] Commands: metaedit
- [ ] Commands: interdiff
- [ ] Commands: evolog
- [ ] New feature: operations log support
- [ ] New Feature: completion for Jj command

## References

Other jujutsu related plugins:

- [https://github.com/NicolasGB/jj.nvim](https://github.com/NicolasGB/jj.nvim)
- [https://github.com/sivansh11/jj](https://github.com/sivansh11/jj)
- [https://github.com/yannvanhalewyn/jujutsu.nvim](https://github.com/yannvanhalewyn/jujutsu.nvim)

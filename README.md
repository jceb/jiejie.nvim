# jiejie

Neovim plugin that adds support for the Jujutsu source control management
system. The design is heavily inspired by
[fugitive.vim](https://github.com/tpope/vim-fugitive).

![jiejie](./jiejie.png)

## Features

- Handling very close to
  [tope's fugitive](https://github.com/tpope/vim-fugitive)
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
  - Squash change or file under the cursor (`ss`, `sS`)
  - Revert change under the cursor (`crc`)
  - Abandon change or file under the cursor (`X`)
  - Rebase change tree or individual change (`rr`, `ro`)
  - Revert last operation (`cU`)

## Installation

With Lazy, add this configuration to nvim:

```lua
return {
  -- https://github.com/jceb/jiejie.nvim.git
  "jceb/jiejie.nvim",
  config = function()
    require("jiejie").setup({})
  end,
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

Priority 1

- [ ] Commands: tag
- [ ] Commands: bookmark
- [ ] Commands: rebase - immutable mappings
- [ ] New Feature: Detect all files/buffers in a jj repository and trigger log
      reloads when they change
- [ ] Commands: split
- [ ] Commands: duplicate
- [ ] Commands: diff
- [ ] Log: support toggling between different log views

Priority 2

- [ ] Commands: Jedit for commits and directories
- [ ] Navigation: pressing <CR> on a hunk should jump to the exact position in
      the buffer
- [ ] Commands: keep diff expansion when reloading the log
- [ ] Commands: worktree
- [ ] Configuration: make mappings configurable
- [ ] Commands: support visual mode for squash, commit, split and restore key
      bindings
- [ ] Key: display full summary of a change via K
- [ ] Docs: make screen recordings of jiejie's usage

Priority 3

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

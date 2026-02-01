# jiejie

Neovim plugin that adds support for the Jujutsu source control management
system. The design is heavily inspired by
[vim-fugitive](https://github.com/tpope/vim-fugitive).

![jiejie](./jiejie.png)

## Features

- UX very close to [tope's vim-fugitive](https://github.com/tpope/vim-fugitive)
  - Toggle inline diff (`=`)
  - Edit file (`<CR>`, `o`, `gO`, `O`)
  - Open revision of a file (`:Jedit [revision]:[file]`, or by selection the
    file in the log summary via `<CR>`, `o`, `gO`, `O`)
  - Open change (`:Jedit [revision]`, `K`)
  - Wraper for `jj` CLI (`:J` or `:Jj`)
- Log buffer (`:J` or `:Jj`)
  - Includes the list of modified files alongside the log
  - Set log to different views (`g1`, `g2`, `g...`)
  - Navigation between changes, files and hunks (`[[`, `]]`, `i`)
  - Increase or decrease the number of log entries shown (`<C-a>`, `<C-x>`)
  - Close buffer (`q`, `gq`)
  - Prepopulate a : command with the file under the cursor (`.`)
- Modify changes from the log buffer
  - Add `!` prefix to mappings for modification of immutable changes
  - Edit change (`<CR>`)
  - Pull and push changes to git (`gp`, `gP`)
  - Modify change description in editor (`de`) or quick edit first line (`dd`)
  - Create a new change after the change under the cursor (`cn`)
  - Commit change or file under the cursor (`cc`)
  - Squash change or file into parent or into change under cursor (`cs`, `cS`)
  - Duplicate change under the cursor (`cd`)
  - Revert change under the cursor (`crc`)
  - Abandon change or file under the cursor (`X`)
  - Rebase change tree or individual change (`rr`, `ro`)
  - Undo last operation (`cU`)
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
- [x] Key: display full summary of a change via K
- [x] Log: support toggling between different log views
- [x] New Feature: Automatically detect changes in files/buffers and reload logs

Priority 1

- [ ] Commands: diff
- [ ] Commands: merge / new with multiple ancestors
- [ ] Fix: restore and squash currently don't work for commits with multiple
      ancestors

Priority 2

- [ ] API: extract commands from buffer.lua and put them in commands.lua
- [ ] Navigation: implement `(, ), [c, ]c and [m, ]m`
- [ ] Commands: keep diff expansion when reloading the log
- [ ] Key: Adjust all bindings to vim.ui.select from the currently visible
      change IDs or enter a custom ID, where needed
- [ ] Key: pressing `X` on a hunk should restore it

Priority 3

- [ ] Commands: Jedit for commits and directories
- [ ] Commands: split (current workaround: commit one file instead of the whole
      change, then squash the other files that should be part of the commit)
- [ ] Docs: make screen recordings of jiejie's usage
- [ ] Refactor: follow lua's style of returning errors
- [ ] Commands: blame
- [ ] Commands: absorb
- [ ] Commands: diffedit
- [ ] Commands: show full change
- [ ] Commands: parallelize
- [ ] Commands: metaedit
- [ ] Commands: interdiff
- [ ] Commands: evolog
- [ ] New feature: operations log support
- [ ] New Feature: completion for Jj command
- [ ] Statusline: provide status line integration
- [ ] Commands: work tree / workspace - not sure what to support here
- [ ] Commands: :Jclog/:Jllog for loading the commit history into the
      quickfix/location list
- [ ] Commands: :Jgrep for loading the commit history into the quickfix list
- [ ] Commands: :Jcd / Jlcd change directory relative to the repository :cd /
      :lcd
- [ ] Commands: :JBrowse open file in browser
- [ ] Commands: support visual mode for squash, commit, split and restore key
      bindings
- [ ] Configuration: make mappings configurable

## References

- [Jujutsu documentation](https://docs.jj-vcs.dev/latest/)
- [Jujutsu's Wiki - Neovim integration](https://github.com/jj-vcs/jj/wiki/Vim,-Neovim)
- [Jujutsu Tutorial by Steve Klabnik](https://steveklabnik.github.io/jujutsu-tutorial/)

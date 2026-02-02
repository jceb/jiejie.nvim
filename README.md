# jiejie

Neovim plugin that adds support for the Jujutsu source control management
system. The design is heavily inspired by
[vim-fugitive](https://github.com/tpope/vim-fugitive).

![jiejie](./jiejie.png)

## Features

- UX very close to [tope's vim-fugitive](https://github.com/tpope/vim-fugitive)
  - Edit file (`<CR>`, `o`, `gO`, `O`)
  - Open revision of a file (`:Jedit [revision]:[file]`, or by selection the
    file in the log summary via `<CR>`, `o`, `gO`, `O`)
  - Open change (`:Jedit [revision]`, `K`)
  - Toggle inline diff (`=`)
  - Edit diff (`:Jdiffsplit [revision]`, `dD`, `dd`, `dV`, `dv`, `dS`, `ds`,
    `dH`, `dh`, `dq`, `d?`)
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
  - Modify change description in editor (`ce`) or quick edit first line (`cd`)
  - Create a new change after the change under the cursor (`cn`)
  - Commit change or file under the cursor (`cc`)
  - Squash change or file into parent or into change under cursor (`cs`, `cS`)
  - Duplicate change under the cursor (`cD`)
  - Revert change under the cursor (`crc`)
  - Abandon change or file under the cursor (`X`)
  - Rebase change tree or individual change (`rr`, `ro`)
  - Undo last operation (`cU`)
  - Bookmark management (`cbc`, `cbX`, `cbx`, `cbF`, `cbf`, `cbM`, `cbm`, `cbr`)
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

See [ROADMAP.md](./ROADMAP.md).

## References

- [Jujutsu documentation](https://docs.jj-vcs.dev/latest/)
- [Jujutsu's Wiki - Neovim integration](https://github.com/jj-vcs/jj/wiki/Vim,-Neovim)
- [Jujutsu Tutorial by Steve Klabnik](https://steveklabnik.github.io/jujutsu-tutorial/)

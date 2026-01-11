# jiejie

Neovim plugin that adds support for the Jujutsu source control management
system. The design is heavily inspired by
[fugitive.vim](https://github.com/tpope/vim-fugitive).

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

## Usage

| Command / Key binding | Description                                          |
| --------------------- | ---------------------------------------------------- |
| `:J` or `:Jj`         | Open or focus log window, when no argument is passed |
| `:Jj <command>`       | Execute `jj <command>`                               |

## Roadmap

- [x] Display log in window
- [x] Make J / JJ a simple wrapper for jj CLI
- [x] Add help header and help key binding
- [x] Add keybinding to edit commits
- [ ] Write and edit commit messages from inside neovim
- [ ] Add more convenience keybindings to perform jj operations
- [ ] Display changed files in log commit view
- [ ] Display file changes as diff inside the log window
- [ ] A completion to Jj command
- [ ] A view of operations log

## References

Other jujutsu related plugins:

- https://github.com/sivansh11/jj
- https://github.com/NicolasGB/jj.nvim

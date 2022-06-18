> This plugin is not stable yet.

# git-blame-virt.nvim

Display `git blame` information of functions, structs and classes using neovim's virt_lines

## Requirements

 - [`neovim >= 0.7.0`](https://neovim.io/)
 - [`git`](https://git-scm.com/)

## Supported Languages

 - Lua
 - Rust
 - C, C++
 - Python
 - Java

## Installation

[packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
	'robert-oleynik/git-blame-virt.nvim',
	requires = { 'nvim-lua/plenary.nvim' },
	config = function()
		require'git-blame-virt'.setup {}
	end
}
```

## Usage

git-blame-virt can be configured using the setup function. Here is an example with the default settings:

```lua
require'git-blame-virt'.setup {
	icons = {
		-- Icon used in front of git commit hashes
		git = '',
		-- Icon used in front of committer
		committer = '👥'
	},
	config = {
		-- Display/Hide shorten commit hash.
		display_commit = false,
		-- Display/Hide names of committers.
		display_committers = true,
		-- Display/Hide names approximate relative time to last commit.
		display_time = true,
		-- Maximum number of names to show
		max_committers = 3
	},
	-- Highlight Group used to display virtual text.
	higroup = 'Comment',
	-- Separator to print between commit, committers and time
	seperator = '|',
	-- Enable to print debugging logs. Not useful for most users.
	debug = false,
}
```

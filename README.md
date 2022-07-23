> This plugin is not stable yet.

# git-blame-virt.nvim

Display `git blame` information of functions, structs and classes using Neovim's virt_lines and TreeSitter.

<div>
<img src="https://user-images.githubusercontent.com/62473688/175044223-6f2ff2f3-a189-4bbc-8b6f-d5d008449402.png" width="700em"/>
</div>


## Requirements

 - [`neovim >= 0.7.0`](https://neovim.io/)
 - [`git`](https://git-scm.com/)

## Supported Languages

 - Lua
 - Rust
 - C, C++
 - Python
 - Java
 - JavaScript
 - LaTeX

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
	allow_foreign_repos = true,
	display = {
		commit_hash = true, -- Enable/Disable latest commit hash
		commit_summary = true, -- Enable/Disable latest commit summary
		commit_committers = true, -- Enable/Disable committers list
		max_committer = 3, -- Limit Number of committers display in list
		commit_time = true, -- Enable/Disable relative commit time
		hi = 'Comment', -- Change Highlight group of default highlight function
		fn = function(...)
			-- See Custom Display Function
		end
	},
	ft = {
		-- Enable/Disable plugin per filetype
		lua = true,
		java = true,
		javascript = true,
		latex = true,
		python = true,
		rust = true,
		cpp = true
	}
}
```

## Custom Display Function

```lua
require'git-blame-virt'.setup {
	-- ...
	display = {
		-- ...
		fn = function(info)
			-- Structure of info: {
			--     committers = { "<name>", ... },
			--     last = {
			--          hash = '000...',
			--          timestamp = 0,
			--          summary = '...',
			--     }
			-- }
			return {
				{ '<text>', '<higlight group>' },
				-- ...
			}
		end
	}
}
```

## Adding Support For Other Languages

> Note: TreeSitter support for that language is required.

### Adding A TreeSitter Query

Add to your config before calling `setup`:

```lua
local lang = require'git-blame-virt.lang'
lang.ts_queries['<your language>'] = [[
	(class_definition) @node
	(function_definition) @node
]]
```

Please note: `@node` is required at the end of each statement.

For Documentation on TreeSitter Queries: see [Pattern Matching With Queries]

[Pattern Matching With Queries]: https://tree-sitter.github.io/tree-sitter/using-parsers#pattern-matching-with-queries


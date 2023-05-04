# nvim-silicon

Plugin to create code images using the external `silicon` tool.

This differs from `silicon.nvim` as that plugin uses a rust binding to call directly into the silicon rust library. That crashed my nvim sometimes on some platforms and I wanted a more resilient solution.

## Features 

Right now, the plugin supports only all options, that the original `silicon` tool offers. The advanced and nice features that @krivahtoo implemented, like window title and watermarking are missing.

This implementation supports selected line ranges and also highlighting of a line and also removing superfluous indents.

### Ranges

If a range is visually selected it does not matter, whether it is block, line or normally selected. The range is then taken as complete lines, where the selection starts up to the line, where the selection ends.
If no selection is made, the whole file is taken as input. If you only want to select a single line, then you would have to manually select it with `Shift-V`.

### Highlighting

You can mark a single line as to be highlighted using the standard vim `mark` command with the mark `h`, the default key combination would be `mh`.

## Setup

With the `lazy.nvim` package manager:

```lua
	{
		"michaelrommel/nvim-silicon",
		lazy = true,
		cmd = "Silicon",
		config = function()
			require("silicon").setup({
				-- Configuration here, or leave empty to use defaults
				font = "VictorMono NF=34;Noto Emoji=34"
			})
		end
	},
```


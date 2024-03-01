# nvim-silicon

Plugin to create code images using the external `silicon` tool.

This differs from `silicon.nvim` as that plugin uses a rust binding to call directly into the silicon rust library.

## Features

Right now, the plugin supports most options, that the original `silicon` tool offers. The advanced and nice features that @krivahtoo implemented, like window title and watermarking are missing. Clipboard support, might not work cross platform, e.g. inside a WSL2 installation, because from there you do not have access to the system clipboard and there may not be an X server running.

This implementation supports selected line ranges, also highlighting of a line and removing superfluous indents and adding consisten padding or a separator between the numbers and the code.

Example code image:

![Example code image](https://raw.githubusercontent.com/michaelrommel/nvim-silicon/main/assets/2024-03-01T16-38-48_code.png)

### Ranges

If a range is visually selected it does not matter, whether it is block, line or normally selected. The range is then taken as complete lines: from the line in which the selection starts up to the line in which the selection ends.
If no selection is made, the whole file is taken as input. If you only want to select a single line, then you would have to manually select it with `Shift-V`.

### Highlighting

You can mark a single line as to be highlighted using the standard vim `mark` command with the mark `h`, the default key combination would be `mh`.

### Gobbling and padding

With the `gobble` parameter set to true, the longest common set of leading whitespace in each line is removed, making it easy to share screenshots of code fragments deep down in a nested structure. However, after removing all that whitespace, you now have the opion to insert arbitrary characters between the line number rendered by `silicon` and the code fragment. Since you can use any string, you can - apart from padding blanks - also insert vertical bars etc.

```lua
    num_separator = "\u{258f} ",
```


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

The `setup` function accepts the following table:

```lua
{
	-- the font settings with size and fallback font
	font = "VictorMono NF=34;Noto Emoji",
	-- the theme to use, depends on themes available to silicon
	theme = "gruvbox-dark",
	-- the background color outside the rendered os window
	background = "#076678",
	-- a path to a background image
	background_image = nil,
	-- the paddings to either side
	pad_horiz = 100,
	pad_vert = 80,
	-- whether to have the os window rendered with rounded corners
	no_round_corner = false,
	-- whether to put the close, minimize, maximise traffic light controls on the border
	no_window_controls = false,
	-- whether to turn off the line numbers
	no_line_number = false,
	-- with which number the line numbering shall start, the default is 1, but here a
	-- function is used to return the actual source code line number
	line_offset = function(args)
		return args.line1
	end,
	-- the distance between lines of code
	line_pad = 0,
	-- the rendering of tab characters as so many space characters
	tab_width = 4,
	-- with which language the syntax highlighting shall be done, should be a function
	-- that returns either a language name or an extension like ".js"
	language = function()
		return vim.bo.filetype
	end,
	-- if the shadow below the os window should have be blurred
	shadow_blur_radius = 16,
	-- the offset of the shadow in x and y directions
	shadow_offset_x = 8,
	shadow_offset_y = 8,
	-- the color of the shadow
	shadow_color = "#100808",
	-- whether to strip of superfluous leading whitespace
	gobble = true,
	-- a string to pad each line with after gobbling removed larger indents,
	-- the default is nil, but here a bar glyph is used to draw a vertial line and some space
	num_separator = "\u{258f} ",
	-- a string or function that defines the path to the output image
	output = function()
		return "./" .. os.date("!%Y-%m-%dT%H-%M-%S") .. "_code.png"
	end,
	-- whether to put the image onto the clipboard, may produce an error if run on WSL2
	to_clipboard = false,
	-- the silicon command, put an absolute location here, if the command is not in your PATH
	command = "silicon",
	-- a string or function returning a string that defines the title showing in the image
	-- only works in silicon versions greater than v0.5.1
	window_title = function()
		return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), ":t")
	end,
}
```

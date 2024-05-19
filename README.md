# nvim-silicon

Plugin to create code images using the external `silicon` tool.

This differs from `silicon.nvim` as that plugin uses a rust binding to call directly into the silicon rust library.

The plugin has been mentioned in a recent YouTube video by "Dreams of Code", titled ["Create beautiful code screenshots in Neovim. Without damaging your wrists."](https://youtu.be/ig_HLrssAYE?si=R2OXs7EgcLZ8dj6r) Thank you, Elliott, for the kind words!

## Features

Right now, the plugin supports most options, that the original `silicon` tool offers. For watermarking an image, you can possibly use a background image with a watermark at the top/bottom edge.

This implementation supports selected line ranges, also highlighting of a line and removing superfluous indents and adding consisten padding or a separator between the numbers and the code. Also now it is possible to configure an output file AND the clipboard as destinations, the code will then call silicon possibly twice. For WSL2 users, a helper script is provided that copies the code screenshot to the Windows clipboard, see explanation below and in the separate document in the `docs` folder.

Example code image:

![Example code image](https://raw.githubusercontent.com/michaelrommel/nvim-silicon/main/assets/2024-03-01T20-33-20_code.png)

The typeface used in this example is called "Victor Mono" from Rune Bjørnerås. You can find it [here](https://rubjo.github.io/victor-mono/). Please consider using this typeface and sponsor Rune as well. Not visible in the screenshot, my go-to terminal emulator is [Wezterm](https://wezfurlong.org/wezterm/index.html). Please show him some love, too.

### Ranges

If a range is visually selected it does not matter, whether it is block, line or normally selected. The range is then taken as complete lines: from the line in which the selection starts up to the line in which the selection ends.
If no selection is made, the whole file is taken as input. If you only want to select a single line, then you would have to manually select it with `Shift-V`.

### Highlighting

You can mark a single line as to be highlighted using the standard vim `mark` command with the mark `h`, the default key combination would be `mh`.

### Colours and background image

You can define either your own solid background colour or provide the path to a background image, setting both is not supported by `silicon` itself. The default colour setting for the shadow colour has also now been removed to let you consistently decide, which colour you want on both accounts.

### Gobbling and padding

With the `gobble` parameter set to true, the longest common set of leading whitespace in each line is removed, making it easy to share screenshots of code fragments deep down in a nested structure. However, after removing all that whitespace, you now have the opion to insert arbitrary characters between the line number rendered by `silicon` and the code fragment. Since you can use any string, you can - apart from padding blanks - also insert vertical bars etc.

```lua
    num_separator = "\u{258f} ",
```

### Language options

The underlying `silicon` command uses the rust `syntect` create for syntax detection and highlighting along with some heuristics. This plugin used the `vim.bo.filetype` as `--language` argument but users reported that some filetypes are not recognized, e.g. fortran.

Therefore - in order not to break existing configs - now the following methods are used:
- if the users set the `language` option in their config, this is used verbatim
- if none is set, first the argument `--language <filetype>` is used as before, but if the `silicon` execution errors out, then
- the file's extension is used as `--language <extension>` argument in a second attempt

This change hopefully does not break s.b. config but improves the chances of getting an image.

### silicon's own config files

`silicon` has the option of using an own config file, usually located at `${HOME}/.config/silicon/config`, but you can find out the location on your system with `silicon --config-file`. There common options can be defined, but the problem is, that command line arguments that `nvim-silicon` supplies and the same arguments in the config file lead to errors.

Now in order to have both worlds, there is now a `disable_defaults` option. This will then only set the command argument. Nothing is added, so if a mandatory option like output destination selection or language is not given either in the config file or the options table, there likely is an error to be expected. So now you can split your arguments between the silicon config file and the neovim lua opts table, depending for instance on how you synchronize your configs across computers. Note that still conflicting arguments in both locations, like `background` and `background_image` still have to be avoided.

Examples:

`~/.config/silicon/config`:
```text
--output="./code.png"
--language="javascript"
--background="#00ff00"
--pad-horiz=10
--pad-vert=5
```

with

`nvim-silicon.lua` for the `lazy` package manager:
```lua
-- create code images
local opts = {
	"michaelrommel/nvim-silicon",
	lazy = true,
	cmd = "Silicon",
	opts = {
		disable_defaults = true
	}
}
return opts
```

will render any file with `javascript` syntax highlighting in a file named `./code.png`.


### Integrating with the Windows Subsystem for Linux

There are now two new options `wslclipboard` and `wslclipboardcopy`, which allow to send code images to the Windows clipboard, even though `nvim` runs inside the WSL, and without installing an X server on Windows and `xclip` on Linux.

The complete rabbit hole journey of this endeavor deserved it's own [description](./docs/wsl2-clipboard.md)



### Lua Keybindings

There was the wish to be able to call directly lua functions for triggering the code images. There are now two entry points available

- `.shoot()`: creates a code image with the default settings
- `.file()`: saves the generated code image only into a file
- `.clip()`: puts the generated code image only onto the clipboard

They can be used with `which-key`, for example, like this:

```lua
wk.register({
	['s'] = {
		name = "Silicon",
		['s']= { function() require("nvim-silicon").shoot() end, "Create code screenshot" },
		['f']= { function() require("nvim-silicon").file() end, "Save code screenshot as file" },
		['c']= { function() require("nvim-silicon").clip() end, "Copy code screenshot to clipboard" },
	},
}, { prefix = "<leader>", mode = "v" })
```

Calling the `.shoot()` function behaves normal, just like calling the `:Silicon` vim command would behave, see the explanation of enabling both file and clipboard destinations below.

On the other hand the `.file()` and `.clip()` functions were thought of as additional, overriding functions, that would en-/disable the `--to-clipboard` and en-/disable the `--output` settings, respectively, for this one invocation.

Because here we manipulate the options table, these new functions may not work well with using a `silicon`-config file as described above. We do not know the settings in that file and the overriding mechanisms may cause conflicting command line and config file settings.


### Setting multiple destinations

There was a request to have the option to generate an image file but also put the image onto the clipboard. Since the `silicon` command only supports an either/or setting, this means we need two calls to `silicon`. Up to now, the options were 1:1 converted into `silicon` arguments and if you had both `--to-clipboard` and `--output` set, `silicon` would throw an error.

Now the plugin interprets this combination as "I want both!" and calls `silicon` twice, one time with the `--output` option and one time with the `--to-clipboard` option. In case the WSL integration is used, the `wslclipboardcopy` option steers, whether to keep or delete the possibly superfluous file.


## Setup

With the `lazy.nvim` package manager:

```lua
{
	"michaelrommel/nvim-silicon",
	lazy = true,
	cmd = "Silicon",
	main = "nvim-silicon",
	opts = {
		-- Configuration here, or leave empty to use defaults
		line_offset = function(args)
			return args.line1
		end,
    }
},
```

**Please note:** When I created this plugin, I hadn't been fully aware of the namespaces that all plugins create. So I named the lua directory differently than the plugin name. In order to avoid name clashes with other modules, I have decided now to move from `require("silicon)` to `require("nvim-silicon)`. If you use the old name, a deprecation warning will show and when you look at `:messages` you should be able to find the place where the deprecated `require()` statements are and convert them. Most likely in the package manager or a key mappings configuration file.

The `setup` function accepts the following table (shown with the builtin defaults, I have selected the defaults in a way, that they should work out of the box on most systems, please customize to your preference. In particular I removed the default output and font settings in order to enable using only the clipboard and make it work for users, who do not have Victor Mono NerdFont installed):

```lua
{
	-- disable_defaults will disable all builtin default settings apart
	-- from the base arguments, that are needed to call silicon at all, see
	-- mandatory_options below, also those options can be overridden
	-- all of the settings could be overridden in the lua setup call,
	-- but this clashes with the use of an external silicon --config=file,
	-- see issue #9
	disable_defaults = false,
	-- turn on debug messages
	debug = false,
	-- most of them could be overridden with other 
	-- the font settings with size and fallback font
	-- Example: font = "VictorMono NF=34;Noto Emoji",
	font = nil
	-- the theme to use, depends on themes available to silicon
	theme = "gruvbox-dark",
	-- the background color outside the rendered os window
	-- (in hexcode string e.g "#076678")
	background = nil,
	-- a path to a background image
	background_image = nil,
	-- the paddings to either side
	pad_horiz = 100,
	pad_vert = 80,
	-- whether to have the os window rendered with rounded corners
	no_round_corner = false,
	-- whether to put the close, minimize, maximise traffic light 
	-- controls on the border
	no_window_controls = false,
	-- whether to turn off the line numbers
	no_line_number = false,
	-- with which number the line numbering shall start
	line_offset = 1,
	-- here a function is used to return the actual source code line number
	-- line_offset = function(args)
	--     return args.line1
	-- end,

	-- the distance between lines of code
	line_pad = 0,
	-- the rendering of tab characters as so many space characters
	tab_width = 4,
	-- with which language the syntax highlighting shall be done, should be
	-- a function that returns either a language name or an extension like "js"
	-- it is set to nil, so you can override it, if you do not set it, we try the
	-- filetype first, and if that fails, the extension
	language = nil
	-- language = function()
	-- 	return vim.bo.filetype
	-- end,
	-- language = function()
	-- 	return vim.fn.fnamemodify(
	-- 		vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()),
	-- 		":e"
	-- 	)
	-- end,

	-- if the shadow below the os window should have be blurred
	shadow_blur_radius = 16,
	-- the offset of the shadow in x and y directions
	shadow_offset_x = 8,
	shadow_offset_y = 8,
	-- the color of the shadow (in hexcode string e.g "#100808")
	shadow_color = nil,
	-- whether to strip of superfluous leading whitespace
	gobble = true,
	-- a string to pad each line with after gobbling removed larger indents,
	num_separator = nil,
	-- here a bar glyph is used to draw a vertial line and some space
	-- num_separator = "\u{258f} ",

	-- whether to put the image onto the clipboard, may produce an error,
	-- if run on WSL2
	to_clipboard = false,
	-- a string or function returning a string that defines the title
	-- showing in the image, only works in silicon versions greater than v0.5.1
	window_title = nil,
	-- here a function is used to get the name of the current buffer
	-- window_title = function()
	--     return vim.fn.fnamemodify(
	--         vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()),
	--         ":t"
	--     )
	-- end,

	-- how to deal with the clipboard on WSL2
	-- possible values are: never, always, auto
	wslclipboard = nil,
	-- what to do with the temporary screenshot image file when using the Windows
	-- clipboard from WSL2, possible values are: keep, delete
	wslclipboardcopy = nil,
	-- the silicon command, put an absolute location here, if the
	-- command is not in your ${PATH}
	command = "silicon",
	-- a string or function that defines the path to the output image
	output = nil
	-- here a function is used to create a file in the current directory
	-- output = function()
	-- 	return "./" .. os.date("!%Y-%m-%dT%H-%M-%SZ") .. "_code.png"
	-- end,
}
```

The mandatory options, that are used, even when the option `disable_defaults` is set to true are:

```lua
-- without that silicon cannot run. But you can override the command
-- option in your lua config
M.mandatory_options = {
	command = 'silicon',
}
```

local M = {}

M.options = {}

-- options, without silicon cannot be run
M.mandatory_options = {
	command = 'silicon',
}

-- default options if nothing is provided by the user
M.default_opts = {
	debug = false,
	font = "VictorMono NF=34;Noto Emoji",
	theme = "gruvbox-dark",
	background = nil,
	background_image = nil,
	pad_horiz = 100,
	pad_vert = 80,
	no_round_corner = false,
	no_window_controls = false,
	no_line_number = false,
	line_offset = 1,
	line_pad = 0,
	tab_width = 4,
	highlight_lines = nil,
	language = nil,
	shadow_blur_radius = 16,
	shadow_offset_x = 8,
	shadow_offset_y = 8,
	shadow_color = nil,
	gobble = true,
	to_clipboard = false,
	window_title = nil,
	num_separator = nil,
	command = "silicon",
	output = function()
		return "./" .. os.date("!%Y-%m-%dT%H-%M-%S") .. "_code.png"
	end,
}

M.parse_options = function(opts)
	local options

	vim.validate({
		opts = { opts, "table" }
	})

	if opts and opts.disable_defaults then
		options = vim.tbl_deep_extend(
			"force",
			M.mandatory_options,
			opts or {}
		)
	else
		options = vim.tbl_deep_extend(
			"force",
			M.default_opts,
			opts or {}
		)
	end

	return options
end

M.get_arguments = function(args, options)
	local cmdline = {}
	local value = nil
	table.insert(cmdline, options.command)
	for k, v in pairs(options) do
		if k == "command" or k == "gobble"
			or k == "num_separator" or k == "disable_defaults"
			or k == "debug" or k == "language"
		then
			-- no-op, since those are not silicon arguments or we deal with
			-- them dynamically later
		elseif k == "output"
			or k == "window_title" or k == "line_offset" then
			table.insert(cmdline, "--" .. string.gsub(k, "_", "-"))
			if type(v) == "function" then
				value = v(args)
			else
				value = v
			end
			table.insert(cmdline, value)
			if k == "output" then M.filename = value end
		else
			if type(v) == "boolean" then
				if v then
					table.insert(cmdline, "--" .. string.gsub(k, "_", "-"))
				end
			elseif type(v) == "nil" then
				-- no-op
			else
				table.insert(cmdline, "--" .. string.gsub(k, "_", "-"))
				table.insert(cmdline, v)
			end
		end
	end

	if options.debug then
		print(require("nvim-silicon.utils").dump(cmdline))
	end
	return cmdline
end

M.format_lines = function(cmdline, args, options)
	local begin_line = args.line1 - 1
	local finish_line = args.line2

	if args.range == 0 then
		begin_line = 0
		finish_line = -1
	end

	local marks = vim.api.nvim_buf_get_mark(vim.api.nvim_win_get_buf(0), "h")[1]
	if marks > 0 then
		local hl
		if args.range == 0 or (args.line1 and marks >= begin_line and marks <= finish_line) then
			hl = marks - begin_line
			table.insert(cmdline, "--highlight-lines")
			table.insert(cmdline, hl)
		end
	end

	local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(0), begin_line, finish_line, false)

	if options.gobble then
		lines = require("nvim-silicon.utils").gobble(lines)
	end
	if options.num_separator then
		lines = require("nvim-silicon.utils").separate(lines, options.num_separator)
	end

	if options.debug then
		print(require("nvim-silicon.utils").dump(lines))
	end
	return lines, cmdline
end

M.shoot = function()
	local args = nil
	local mode = vim.api.nvim_get_mode().mode
	if mode == "n" then
		args = {
			line1 = 0,
			line2 = -1,
			range = 0
		}
	elseif mode == "v" or mode == "V" or mode == "\22" then
		local line1 = vim.fn.getpos("v")[2]
		local line2 = vim.api.nvim_win_get_cursor(0)[1]
		if line1 > line2 then
			local linetmp = line1
			line1 = line2
			line2 = linetmp
		end
		args = {
			line1 = line1,
			line2 = line2,
			range = 1
		}
	end
	if M.options.debug then
		print("mode is: " .. mode)
		print("args: " .. require("nvim-silicon.utils").dump(args))
	end
	M.start(args, M.options)
end

M.start = function(args, options)
	local lines = nil
	local cmdline = nil
	-- build the commandline based on supplied options
	local base_cmdline = M.get_arguments(args, options)
	-- parse buffer into lines, based on arguments from neovim, reshapes cmdline
	lines, base_cmdline = M.format_lines(base_cmdline, args, options)

	local ret
	local value
	-- if a language was supplied by the user, take that as argument directly
	if options.language then
		if type(options.language) == "function" then
			value = options.language()
		else
			value = options.language
		end

		cmdline = vim.tbl_extend("error", base_cmdline, {})
		table.insert(cmdline, '--language')
		table.insert(cmdline, value)
		if options.debug then
			print(require("nvim-silicon.utils").dump(cmdline))
		end
		ret = vim.fn.system(cmdline, lines)
		ret = string.gsub(ret, "\n", "")
	else
		if options.disable_defaults then
			-- run silicon as is, no supplement of anything
			if options.debug then
				print(require("nvim-silicon.utils").dump(base_cmdline))
			end
			ret = vim.fn.system(base_cmdline, lines)
			ret = string.gsub(ret, "\n", "")
		else
			-- try first the language parameter derived from the buffer's filetype
			cmdline = vim.tbl_extend("error", base_cmdline, {})
			table.insert(cmdline, '--language')
			table.insert(cmdline, vim.bo.filetype)
			if options.debug then
				print(require("nvim-silicon.utils").dump(cmdline))
			end
			ret = vim.fn.system(cmdline, lines)
			ret = string.gsub(ret, "\n", "")
			if ret ~= "" then
				vim.notify(
					"silicon call with filetype error: " .. ret .. ", trying extension...",
					vim.log.levels.WARN,
					{ title = "nvim-silicon" }
				)
				-- seems to have gone wrong, new try with extension
				cmdline = vim.tbl_extend("error", base_cmdline, {})
				table.insert(cmdline, '--language')
				table.insert(cmdline, vim.fn.fnamemodify(
					vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()),
					":e"
				))
				if options.debug then
					print(require("nvim-silicon.utils").dump(cmdline))
				end
				ret = vim.fn.system(cmdline, lines)
				ret = string.gsub(ret, "\n", "")
			end
		end
	end

	-- last, final attempt being evaluated
	if ret ~= "" then
		return vim.notify(
			"silicon returned with: " .. ret,
			vim.log.levels.WARN,
			{ title = "nvim-silicon" }
		)
	else
		if options.to_clipboard then
			return vim.notify(
				"silicon put the image on the clipboard",
				vim.log.levels.INFO,
				{ title = "nvim-silicon" }
			)
		else
			local genInfo = function()
				local location = nil
				if not M.filename then
					location = "the location specified in your config file"
				elseif string.sub(tostring(M.filename), 1, 1) == "~" then
					location = M.filename
				elseif string.sub(tostring(M.filename), 1, 2) == "./" then
					location = vim.fn.getcwd() .. string.sub(tostring(M.filename), 2)
				else
					location = vim.fn.getcwd() .. "/" .. M.filename
				end
				return "silicon generated an image at " .. location
			end
			return vim.notify(genInfo(), vim.log.levels.INFO, { title = "nvim-silicon" })
		end
	end
end

M.setup = function(opts)
	-- populate the global options table
	M.options = M.parse_options(opts)

	-- define commands for neovim
	vim.api.nvim_create_user_command("Silicon", function(args)
		M.start(args, M.options)
	end, {
		desc = "convert range to code image representation",
		force = false,
		range = true
	})
end

return M

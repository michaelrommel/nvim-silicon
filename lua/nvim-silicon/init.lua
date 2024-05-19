local M = {}

M.utils = require("nvim-silicon.utils")

M.options = {}

-- options, without silicon cannot be run
M.mandatory_options = {
	command = 'silicon',
}

-- default options if nothing is provided by the user
M.default_opts = {
	debug = false,
	font = nil,
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
	wslclipboard = nil,
	command = "silicon",
	output = nil,
}

M.get_helper_path = function()
	return debug.getinfo(2, "S").source:sub(2):match("(.*/).*/.*/") .. "helper/wslclipimg"
end

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
			or k == "wslclipboard" or k == "wslclipboardcopy"
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
		print(M.utils.dump(cmdline))
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
		lines = M.utils.gobble(lines)
	end
	if options.num_separator then
		lines = M.utils.separate(lines, options.num_separator)
	end

	if options.debug then
		print(M.utils.dump(lines))
	end
	return lines, cmdline
end

M.cmd = function(args, options)
	local lines = nil
	local cmdline = nil

	-- build the commandline based on supplied options
	local base_cmdline = M.get_arguments(args, options)
	-- parse buffer into lines, based on arguments from neovim, reshapes cmdline
	lines, base_cmdline = M.format_lines(base_cmdline, args, options)

	local ret = {}
	local code
	-- if a language was supplied by the user, take that as argument directly
	if options.language then
		if type(options.language) == "function" then
			ret.language = options.language()
		else
			ret.language = options.language
		end

		cmdline = vim.tbl_extend("error", base_cmdline, {})
		table.insert(cmdline, '--language')
		table.insert(cmdline, ret.language)
		if options.debug then
			print(M.utils.dump(cmdline))
		end
		code = vim.fn.system(cmdline, lines)
		code = string.gsub(code, "\n", "")
		ret.code = code
	else
		if options.disable_defaults then
			-- run silicon as is, no supplement of anything
			if options.debug then
				print(M.utils.dump(base_cmdline))
			end
			code = vim.fn.system(base_cmdline, lines)
			code = string.gsub(code, "\n", "")
			ret.language = nil
			ret.code = code
		else
			-- try first the language parameter derived from the buffer's filetype
			cmdline = vim.tbl_extend("error", base_cmdline, {})
			ret.language = vim.bo.filetype
			table.insert(cmdline, '--language')
			table.insert(cmdline, ret.language)
			if options.debug then
				print(M.utils.dump(cmdline))
			end
			code = vim.fn.system(cmdline, lines)
			code = string.gsub(code, "\n", "")
			ret.code = code
			print(M.utils.dump(code))
			if code ~= "" then
				vim.notify(
					"silicon call with filetype error: " .. code .. ", trying extension...",
					vim.log.levels.WARN,
					{ title = "nvim-silicon" }
				)
				-- seems to have gone wrong, new try with extension
				cmdline = vim.tbl_extend("error", base_cmdline, {})
				ret.language = vim.fn.fnamemodify(
					vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()),
					":e"
				)
				table.insert(cmdline, '--language')
				table.insert(cmdline, ret.language)
				if options.debug then
					print(M.utils.dump(cmdline))
				end
				code = vim.fn.system(cmdline, lines)
				code = string.gsub(code, "\n", "")
				ret.code = code
			end
		end
	end

	-- last, final attempt being evaluated
	if code ~= "" then
		vim.notify(
			"silicon returned with: " .. code,
			vim.log.levels.WARN,
			{ title = "nvim-silicon" }
		)
	else
		if options.to_clipboard then
			vim.notify(
				"silicon put the image on the clipboard",
				vim.log.levels.INFO,
				{ title = "nvim-silicon" }
			)
		else
			local get_location = function()
				local location = nil
				if not M.filename then
					location = "the location specified in your config file"
				elseif string.sub(tostring(M.filename), 1, 1) == "~" then
					location = M.filename
				elseif string.sub(tostring(M.filename), 1, 2) == "./" then
					location = vim.fn.getcwd() .. string.sub(tostring(M.filename), 2)
				else
					-- location = vim.fn.getcwd() .. "/" .. M.filename
					location = M.filename
				end
				return location
			end
			ret.location = get_location()
			vim.notify(
				"silicon generated an image at " .. ret.location,
				vim.log.levels.INFO,
				{ title = "nvim-silicon" }
			)
		end
	end
	return ret
end

M.start = function(args, opts)
	local options
	local code
	local ret = nil
	-- make a deep copy of the original options
	options = vim.tbl_deep_extend(
		"force",
		opts,
		{}
	)

	if (not opts.output) and (not opts.to_clipboard) and (not opts.disable_defaults) then
		-- the user has not supplied any valid destination and not disabled defaults
		-- so add the default output file destination function that we used before
		if opts.debug then
			print("setting default output function")
		end
		opts.output = true
		options.output = function()
			return "./" .. os.date("!%Y-%m-%dT%H-%M-%SZ") .. "_code.png"
		end
	end

	-- if wished for, let's create the file first
	if opts.output then
		options.to_clipboard = false
		ret = M.cmd(args, options)
	end

	if opts.to_clipboard then
		-- check whether wsl detection shall be done
		if (opts.wslclipboard == "auto" and M.utils.is_wsl()) or
			(opts.wslclipboard == "always") then
			-- we want to use the WSL integration
			local cmdline = {}
			table.insert(cmdline, "/bin/bash")
			table.insert(cmdline, M.helper)
			if ret and ret.location then
				-- we have already a file, need to send it to the windows side
				table.insert(cmdline, ret.location)
			else
				-- we need to create a temporary file
				options.output = "/tmp/" .. os.date("!%Y-%m-%dT%H-%M-%SZ") .. "_code.png"
				options.to_clipboard = false
				ret = M.cmd(args, options)
				if ret and ret.location then
					-- now we have a file, need to send it to the windows side
					table.insert(cmdline, ret.location)
				else
					-- notify user that the tmp image generation failed
					vim.notify(
						"silicon returned with: " .. ret.code,
						vim.log.levels.WARN,
						{ title = "nvim-silicon" }
					)
					return
				end
			end
			if opts.debug then
				print(M.utils.dump(cmdline))
			end
			code = vim.fn.system(cmdline)
			code = string.gsub(code, "\n", "")
			if code ~= "" then
				vim.notify(
					"wslclipimg returned with: " .. code,
					vim.log.levels.WARN,
					{ title = "nvim-silicon" }
				)
			else
				vim.notify(
					"wslclipimg put the image at " .. ret.location .. " onto the clipboard",
					vim.log.levels.INFO,
					{ title = "nvim-silicon" }
				)
			end
			-- file based outp[ut was not desired, so we created a tmp file
			if (not opts.output) and (opts.wslclipboardcopy == "delete") then
				-- we should clean that tmp file now
				local _, err = os.remove(ret.location)
				if err then
					vim.notify(
						"wslclipimg could not delete the tmp file: " .. err,
						vim.log.levels.WARN,
						{ title = "nvim-silicon" }
					)
				end
			end
		else
			-- we want the standard way of putting an image onto the clipboard
			if ret and ret.code == "" and ret.language then
				-- we already know which language works
				options.language = ret.language
			end
			options.output = nil
			options.to_clipboard = true
			ret = M.cmd(args, options)
		end
	end
end

M.shoot = function(opts)
	local options
	-- we get overridden options, if we are called from
	-- .clip() or .file()
	if opts then
		options = opts
	else
		options = M.options
	end

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
		print("args: " .. M.utils.dump(args))
	end
	M.start(args, options)
end

M.file = function()
	local options
	-- make a deep copy of the original options
	options = vim.tbl_deep_extend(
		"force",
		M.options,
		{}
	)
	options.to_clipboard = false
	-- if not options.output then
	-- 	print("You triggered the .file() function, but forgot to set an output path")
	-- 	options.output = "/tmp/" .. os.date("!%Y-%m-%dT%H-%M-%SZ") .. "_code.png"
	-- end
	M.shoot(options)
end

M.clip = function()
	local options
	-- make a deep copy of the original options
	options = vim.tbl_deep_extend(
		"force",
		M.options,
		{}
	)
	options.to_clipboard = true
	options.output = nil
	M.shoot(options)
end

M.setup = function(opts)
	-- populate the global options table
	M.options = M.parse_options(opts)
	-- find my own path
	M.helper = M.get_helper_path()
	if M.options.debug then
		print("helper is at: " .. M.helper)
	end

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

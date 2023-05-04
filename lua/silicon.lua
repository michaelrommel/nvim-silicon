local M = {}

M.default_opts = {
	font = "VictorMono Nerd Font=34;Noto Emoji",
	theme = "gruvbox-dark",
	background = "#076678",
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
	language = function()
		return vim.bo.filetype
	end,
	shadow_blur_radius = 16,
	shadow_offset_x = 8,
	shadow_offset_y = 8,
	shadow_color = "#100808",
	output = function()
		return "./" .. os.date("!%Y-%m-%dT%H-%M-%S") .. "_code.png"
	end,
	command = "silicon"
}

M.start = function(args)
	print("Silicon started")
	local cmdline = {}
	table.insert(cmdline, M.opts.command)
	for k, v in pairs(M.opts) do
		if k == "command" then
			-- no-op
		elseif k == "language" then
			table.insert(cmdline, '--language')
			if type(v) == "function" then
				table.insert(cmdline, v())
			else
				table.insert(cmdline, v)
			end
		elseif k == "output" then
			table.insert(cmdline, '--output')
			if type(v) == "function" then
				table.insert(cmdline, v())
			else
				table.insert(cmdline, v)
			end
		else
			if type(v) == "boolean" then
				if v then
					table.insert(cmdline, "--" .. string.gsub(k, "_", "-"))
				end
			elseif type(v) == "number" then
				table.insert(cmdline, "--" .. string.gsub(k, "_", "-"))
				table.insert(cmdline, v)
			elseif type(v) == "nil" then
				-- no-op
			else
				table.insert(cmdline, "--" .. string.gsub(k, "_", "-"))
				table.insert(cmdline, v)
			end
		end
	end
	local marks = vim.api.nvim_buf_get_mark(vim.api.nvim_win_get_buf(0), "h")[1]
	if marks > 0 then
		local hl
		if args.line1 and marks >= (args.line1 - 1) and marks <= args.line2 then
			hl = marks - (args.line1 - 1)
			table.insert(cmdline, "--highlight-lines")
			table.insert(cmdline, hl)
		end
	end
	local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(0), args.line1 - 1, args.line2, false)
	local ret = vim.fn.system(cmdline, lines)
	print(ret)
end

M.setup = function(opts)
	vim.validate({
		opts = { opts, "table" }
	})

	M.opts = vim.tbl_deep_extend(
		"force",
		M.default_opts,
		opts or {}
	)

	vim.api.nvim_create_user_command("Silicon", function(args)
		M.start(args)
	end, {
		desc = "convert range to code image representation",
		force = false,
		range = true
	})
end

return M

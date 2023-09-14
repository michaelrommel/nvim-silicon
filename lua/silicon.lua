local M = {}

M.default_opts = {
	font = "VictorMono NF=34;Noto Emoji",
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
	gobble = true,
	output = function()
		return "./" .. os.date("!%Y-%m-%dT%H-%M-%S") .. "_code.png"
	end,
	to_clipboard = false,
	command = "silicon",
}

M.start = function(args)
	local cmdline = {}
	local filename = nil
	local value = nil
	table.insert(cmdline, M.opts.command)
	for k, v in pairs(M.opts) do
		if k == "command" or k == "gobble" then
			-- no-op
		elseif k == "language" or k == "output"
			or k == "window_title" or k == "line_offset" then
			table.insert(cmdline, "--" .. string.gsub(k, "_", "-"))
			if type(v) == "function" then
				value = v(args)
			else
				value = v
			end
			table.insert(cmdline, value)
			if k == "output" then filename = value end
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
	-- print(require("utils").dump(args))

	local start = args.line1 - 1
	local fin = args.line2

	if args.range == 0 then
		start = 0
		fin = -1
	end

	local marks = vim.api.nvim_buf_get_mark(vim.api.nvim_win_get_buf(0), "h")[1]
	if marks > 0 then
		local hl
		if args.range == 0 or (args.line1 and marks >= start and marks <= fin) then
			hl = marks - start
			table.insert(cmdline, "--highlight-lines")
			table.insert(cmdline, hl)
		end
	end

	local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(0), start, fin, false)

	if M.opts.gobble then
		lines = require("utils").gobble(lines)
	end
	-- print(require("utils").dump(lines))

	local ret = vim.fn.system(cmdline, lines)
	if ret ~= "" then
		return vim.notify(
			"silicon returned with: " .. ret,
			vim.log.levels.WARN,
			{ title = "nvim-silicon" }
		)
	else
		if M.opts.to_clipboard then
			return vim.notify(
				"silicon generated image was put on the clipboard",
				vim.log.levels.INFO,
				{ title = "nvim-silicon" }
			)
		else
			return vim.notify(
				"silicon generated image: " .. vim.fn.getcwd() .. "/" .. filename,
				vim.log.levels.INFO,
				{ title = "nvim-silicon" }
			)
		end
	end
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

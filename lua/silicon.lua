local M = {}

M.default_opts = {
	font = "VictorMono-NF=34;Noto Emoji=34;",
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
	gobble = true,
	highlight_lines = true,
	shadow_blur_radius = 16,
	shadow_offset_x = 8,
	shadow_offset_y = 8,
	shadow_color = "#100808",
	output = function()
		return "./" .. os.date("!%Y-%m-%dT%H:%M:%S") .. "_screenshot.png"
	end,
	command = "silicon"
}

M.start = function()
	print("Silicon started")
	local args = ""
	for k, v in pairs(M.opts) do
		if k ~= "command" then
			args = args .. " --" .. string.gsub(k, "_", "-")
		end
	end
	print(M.opts.command .. args)
end

M.setup = function(opts)
	vim.validate({
		opts = { opts, "table" }
	})

	M.opts = vim.tbl_deep_extend({
		"force",
		M.default_opts,
		opts
	})

	vim.api.nvim_create_user_command("Silicon", function(_)
		M.start()
	end, {
		bang = true,
		desc = "require('silicon').start()",
		nargs = 0,
		bar = true,
	})
end

return M

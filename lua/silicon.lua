local M = {}

M.start = function()
	print("Silicon started")
end

M.setup = function(opts)
	vim.validate({
		opts = { opts, "table" }
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

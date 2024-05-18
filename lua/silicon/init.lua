local M = {}

vim.deprecate(
	"require(\"silicon\")",
	"require(\"nvim-silicon\")",
	"v1.2",
	"nvim-silicon",
	true
)
M = require('nvim-silicon')

return M

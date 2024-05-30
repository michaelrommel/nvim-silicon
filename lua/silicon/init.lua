local M = {}

-- In the next release use the deprecation function to
-- alert users. For now a message addendum should suffice.
-- vim.deprecate(
-- 	"require(\"silicon\")",
-- 	"require(\"nvim-silicon\")",
-- 	"v1.2",
-- 	"nvim-silicon",
-- 	true
-- )

M = require('nvim-silicon')
M.message = " Please use 'require(\"nvim-silicon\")' now, see README!"
return M

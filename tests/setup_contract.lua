vim.opt.rtp:prepend(vim.fn.getcwd())
local tools = require("lua_tools")
assert(not package.loaded["lua_tools.workspace"], "require alone has no listeners")
assert(not tools.info().enabled)
local opts = { config_roots = { "/a" }, library = { { path = "/b", words = { "vim" } } } }
local copy = vim.deepcopy(opts)
tools.setup(opts)
assert(vim.deep_equal(opts, copy))
assert(not package.loaded["lua_tools.resolve"] and not package.loaded["lua_tools.scan"])
assert(not package.loaded["lua_tools.nvim"], "empty startup does not collect plugin directories")
local handlers = vim.api.nvim_get_autocmds({ group = "LuaTools" })
local commands = vim.api.nvim_get_commands({})
for _, invalid in ipairs({
  false,
  { nvim = "yes" },
  { config_roots = { false } },
  { plugins = {} },
  { debounce = math.huge },
  { library = { { path = "/x", words = { "[" } } } },
}) do
  assert(not pcall(tools.setup, invalid))
  assert(vim.deep_equal(commands, vim.api.nvim_get_commands({})))
  assert(vim.deep_equal(handlers, vim.api.nvim_get_autocmds({ group = "LuaTools" })))
end
tools.setup(opts)
assert(#vim.api.nvim_get_autocmds({ group = "LuaTools" }) == #handlers)
vim.api.nvim_create_user_command("LuaTools", function() end, { force = true })
assert(not pcall(tools.setup, opts), "a replaced command is preserved")
assert(tools.info().enabled, "conflict does not dispose the active configuration")
tools.dispose()
assert(vim.fn.exists(":LuaTools") == 2)
vim.api.nvim_del_user_command("LuaTools")
tools.setup({ enabled = false })
assert(not tools.info().enabled and vim.fn.exists(":LuaTools") == 0)
tools.dispose()
print("PASS cold setup, LuaDoc entry points, option isolation, atomic validation, repeated setup and command ownership")

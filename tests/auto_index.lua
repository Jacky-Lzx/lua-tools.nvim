vim.opt.rtp:prepend(vim.fn.getcwd())
local api, uv = vim.api, vim.uv
local temp = assert(uv.fs_mkdtemp((vim.env.TMPDIR or "/tmp") .. "/lua-tools-unit-XXXXXX"))
temp = assert(uv.fs_realpath(temp))
local function library(dir)
  vim.fn.mkdir(dir .. "/lua", "p")
  vim.fn.writefile({ "error('library sources must not execute')" }, dir .. "/lua/unloaded.lua")
  return dir
end
local root, cold, external = temp .. "/config", library(temp .. "/cold,中文"), library(temp .. "/external")
vim.fn.mkdir(root, "p")
assert(uv.fs_symlink(root, temp .. "/alias"))
local inactive = library(temp .. "/inactive")
local function buffer(file)
  local buf = api.nvim_create_buf(true, false)
  api.nvim_buf_set_name(buf, file)
  api.nvim_buf_set_lines(buf, 0, -1, false, { "---@type FixtureOptions", "local opts = {}", "return opts" })
  vim.bo[buf].filetype = "lua"
  return buf
end
local configbuf = buffer(temp .. "/alias/new.lua")
local ordinary = buffer(temp .. "/configuration/main.lua")
local function client(id, buf, dir)
  return {
    id = id,
    name = "lua_ls",
    root_dir = dir,
    initialized = true,
    attached_buffers = { [buf] = true },
    settings = { Lua = { workspace = { library = { "/user-library" } }, diagnostics = { globals = { "mine" } } } },
    is_stopped = function()
      return false
    end,
    calls = 0,
    notify = function(self, method)
      assert(method == "workspace/didChangeConfiguration")
      self.calls = self.calls + 1
    end,
  }
end
local first, second = client(1, configbuf, root), client(2, ordinary, temp .. "/configuration")
local before = vim.deepcopy(first.settings)
local original = vim.lsp.get_clients
vim.lsp.get_clients = function()
  return { first, second }
end
local selected = {
  { dir = cold, state = { phase = "registered" } },
  { dir = cold }, -- shared components deduplicate
  { dir = external },
  { dir = inactive, selected = false },
  { dir = temp .. "/absent", state = { phase = "missing" } },
}
local tools = require("lua_tools")
local function setup(extra)
  tools.setup(vim.tbl_extend("force", {
    config_roots = { root },
    plugins = function()
      return selected
    end,
    debounce = 1,
  }, extra or {}))
end
local function has(c, dir)
  return vim.tbl_contains(c.settings.Lua.workspace.library, dir .. "/lua")
end
-- Default roots honor stdpath and an explicitly selected init.lua.
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind)
  return kind == "config" and root or stdpath(kind)
end
assert(require("lua_tools.nvim").matches(first, { configbuf }, {}))
vim.fn.stdpath = stdpath
local myvimrc = vim.env.MYVIMRC
vim.env.MYVIMRC = root .. "/init.lua"
assert(require("lua_tools.nvim").matches(first, { configbuf }, {}))
vim.env.MYVIMRC = myvimrc
-- Active runtime roots include a manager without its own declaration. Escaped
-- commas remain intact and the config's own source is not treated as a library.
local host = library(temp .. "/host,manager")
library(root)
local runtime = vim.o.runtimepath
vim.o.runtimepath = vim.fn.escape(host, ",\\") .. "," .. vim.fn.escape(root, ",\\") .. "," .. runtime
setup()
assert(has(first, host) and not has(first, root))
assert(has(first, cold) and has(first, external), "config indexes cold and external plugins without require hints")
assert(not has(first, inactive) and not has(second, cold), "inactive plugins and ordinary projects stay isolated")
assert(vim.tbl_contains(first.settings.Lua.workspace.library, "/user-library"))
local count = 0
for _, path in ipairs(first.settings.Lua.workspace.library) do
  if path == cold .. "/lua" then
    count = count + 1
  end
end
assert(count == 1, "shared package roots deduplicate")
assert(
  require("lua_tools.path").contains(root, temp .. "/alias/not-created/new.lua"),
  "unsaved symlink paths are detected"
)
assert(
  not require("lua_tools.path").contains(root, temp .. "/configuration/main.lua"),
  "directory boundaries are exact"
)
local info = tools.info()
assert(info.workspaces[1].nvim and not info.workspaces[2].nvim)
info.workspaces[1].library[1] = "changed"
assert(tools.info().workspaces[1].library[1] ~= "changed")
local calls = first.calls
tools.refresh()
assert(first.calls == calls, "unchanged settings do not notify")
selected = { { dir = external } }
api.nvim_exec_autocmds("BufEnter", { buffer = configbuf })
assert(
  vim.wait(1000, function()
    return not has(first, cold)
  end, 10),
  "selected directories update on buffer events"
)
assert(has(first, external))
setup({ nvim = false })
assert(not has(first, external), "nvim=false disables full plugin indexing")
-- The optional plugin-tools adapter uses its public status API without loading a manager.
local old_manager = package.loaded.plugin_tools
package.loaded.plugin_tools = {
  status = function()
    return { { dir = cold } }
  end,
}
tools.setup({ config_roots = { root } })
assert(has(first, cold), "already-loaded manager provides actual selected directories")
package.loaded.plugin_tools = old_manager
-- Attached config files also work when LuaLS chooses a broader workspace root.
first.root_dir = temp
setup()
assert(has(first, external))
api.nvim_buf_set_name(configbuf, temp .. "/outside/new.lua")
tools.refresh()
assert(not has(first, external), "leaving config buffers releases config-only libraries")
first.root_dir = root
-- A project-owned library remains owned by the user during teardown.
first.settings.Lua.workspace.library[#first.settings.Lua.workspace.library + 1] = external .. "/lua"
setup()
tools.dispose()
assert(vim.tbl_contains(first.settings.Lua.workspace.library, external .. "/lua"))
assert(vim.deep_equal(first.settings.Lua.diagnostics, before.Lua.diagnostics))
assert(vim.fn.exists(":LuaTools") == 0)
tools.refresh()
assert(not tools.info().enabled and #tools.info().workspaces == 0, "refresh after disposal stays disabled")
vim.lsp.get_clients = original
vim.o.runtimepath = runtime
for _, buf in ipairs({ configbuf, ordinary }) do
  api.nvim_buf_delete(buf, { force = true })
end
assert(not package.loaded.unloaded, "indexing must not execute plugin sources")
vim.fn.delete(temp, "rf")
print(
  "PASS config detection, symlinks, cold/dev directories, manager adapter, deduplication, project isolation and cleanup"
)

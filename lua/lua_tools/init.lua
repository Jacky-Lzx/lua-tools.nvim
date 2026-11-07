---@class lua_tools.API
local M = {}

---Configure LuaLS development libraries; source files are never executed.
---@param opts? lua_tools.Options
---@return lua_tools.API
function M.setup(opts)
  assert(opts == nil or type(opts) == "table", "lua-tools: setup expects a table")
  require("lua_tools.workspace").setup(vim.deepcopy(opts or {}))
  return M
end

---Recompute libraries, optionally invalidating module and buffer caches.
---@param reset? boolean
function M.refresh(reset)
  local workspace = package.loaded["lua_tools.workspace"]
  if workspace then
    workspace.refresh(reset)
  end
end

---Stop listeners and restore only owned client settings and commands.
function M.dispose()
  local workspace = package.loaded["lua_tools.workspace"]
  if workspace then
    workspace.disable()
  end
end

---Return copied client roots and library paths without starting an LSP server.
---@return lua_tools.Info
function M.info()
  local workspace = package.loaded["lua_tools.workspace"]
  return workspace and workspace.info() or { enabled = false, workspaces = {} }
end

return M

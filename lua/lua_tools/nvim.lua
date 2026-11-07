local Path = require("lua_tools.path")
local M = {}

local function config_roots(opts)
  local roots = { vim.fn.stdpath("config") }
  local init = vim.env.MYVIMRC
  if init and vim.fs.basename(init) == "init.lua" then
    roots[#roots + 1] = vim.fs.dirname(init)
  end
  vim.list_extend(roots, opts.config_roots or {})
  return roots
end

function M.matches(client, buffers, opts)
  if opts.nvim == false then
    return false
  end
  local roots = config_roots(opts)
  for _, root in ipairs(roots) do
    if type(client.root_dir) == "string" and Path.contains(root, client.root_dir) then
      return true
    end
    for _, buf in ipairs(buffers) do
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and Path.contains(root, name) then
        return true
      end
    end
  end
  return false
end

local function plugins(opts)
  if opts.plugins then
    return opts.plugins()
  end
  -- Optional adapter: never require or activate a manager merely to index types.
  local manager = package.loaded.plugin_tools
  if manager and type(manager.status) == "function" then
    local ok, items = pcall(manager.status)
    if ok then
      return items
    end
  end
end

function M.libraries(opts)
  local dirs, seen, configs = {}, {}, {}
  for _, root in ipairs(config_roots(opts)) do
    configs[Path.normalize(root)] = true
  end
  local function add(dir)
    if
      type(dir) == "string"
      and dir ~= ""
      and not configs[Path.normalize(dir)]
      and vim.fn.isdirectory(dir .. "/lua") == 1
    then
      local path = Path.normalize(dir .. "/lua")
      if not seen[path] then
        seen[path], dirs[#dirs + 1] = true, path
      end
    end
  end
  local items = plugins(opts)
  if items ~= nil then
    assert(type(items) == "table" and vim.islist(items), "lua-tools: plugins() must return a list or nil")
    for _, item in ipairs(items) do
      assert(type(item) == "table" and type(item.dir) == "string", "lua-tools: plugin entries need a dir")
      if item.selected ~= false and not (item.state and item.state.phase == "missing") then
        add(item.dir)
      end
    end
  end
  -- Runtime roots include the host manager itself, which need not have a spec.
  for _, dir in ipairs(Path.runtime()) do
    add(dir)
  end
  table.sort(dirs)
  return dirs
end

return M

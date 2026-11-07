local M = {}
local api = vim.api
local opts, clients, cache = {}, {}, {}
local group, timer, generation = nil, nil, 0
local configured = false
local fields = { { "runtime", "version" }, { "runtime", "path" }, { "workspace", "checkThirdParty" } }
local defaults = {
  runtime = { version = "LuaJIT", path = { "?.lua", "?/init.lua", "lua/?.lua", "lua/?/init.lua" } },
  workspace = { checkThirdParty = false },
}

local function allowed(client)
  local root = client.root_dir or vim.fn.getcwd()
  if type(opts.enabled) == "function" then
    return opts.enabled(root)
  elseif opts.enabled ~= nil then
    return opts.enabled
  end
  return not (vim.uv.fs_stat(root .. "/.luarc.json") or vim.uv.fs_stat(root .. "/.luarc.jsonc"))
end
local function notify(client)
  if not client:is_stopped() then
    client:notify("workspace/didChangeConfiguration", { settings = client.settings })
  end
end
local function restore(state)
  local client = state.client
  local lua = vim.tbl_get(client.settings, "Lua")
  if not lua then
    return
  end
  if vim.deep_equal(lua, state.applied) then
    client.settings.Lua = vim.deepcopy(state.before)
  else
    local libraries = vim.tbl_get(lua, "workspace", "library")
    if libraries and vim.islist(libraries) then
      lua.workspace.library = vim.tbl_filter(function(path)
        return not state.added[path]
      end, libraries)
    end
    for _, field in ipairs(fields) do
      if lua[field[1]] and vim.deep_equal(lua[field[1]][field[2]], vim.tbl_get(state.applied or {}, unpack(field))) then
        lua[field[1]][field[2]] = vim.deepcopy(vim.tbl_get(state.before or {}, unpack(field)))
      end
    end
  end
  notify(client)
end
local function scan(buf)
  local tick = api.nvim_buf_get_changedtick(buf)
  local filename = api.nvim_buf_get_name(buf)
  if cache[buf] and cache[buf].tick == tick and cache[buf].name == filename then
    return cache[buf].paths
  end
  local paths = {}
  if api.nvim_buf_get_offset(buf, api.nvim_buf_line_count(buf)) <= (opts.max_bytes or 1024 * 1024) then
    local text = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local resolver = require("lua_tools.resolve")
    local modules = require("lua_tools.scan").modules(text)
    local function add(path)
      if path then
        paths[path] = true
      end
    end
    for mod in pairs(modules) do
      add(resolver.module(mod, opts))
    end
    local name = api.nvim_buf_get_name(buf)
    for _, spec in ipairs(opts.library or {}) do
      spec = type(spec) == "string" and { path = spec } or spec
      local matches = #(spec.words or {}) + #(spec.mods or {}) + #(spec.files or {}) == 0
      for _, word in ipairs(spec.words or {}) do
        matches = matches or text:find(word) ~= nil
      end
      for _, mod in ipairs(spec.mods or {}) do
        for name in pairs(modules) do
          matches = matches or name == mod or name:sub(1, #mod + 1) == mod .. "."
        end
      end
      for _, file in ipairs(spec.files or {}) do
        matches = matches or name:find(file) ~= nil
      end
      if matches then
        add(resolver.library(spec.path, opts))
      end
    end
  end
  cache[buf] = { tick = tick, name = filename, paths = paths }
  return paths
end

function M.refresh(reset)
  if not configured then
    return
  end
  if reset then
    cache = {}
    require("lua_tools.resolve").reset()
  end
  local live = {}
  for _, client in ipairs(vim.lsp.get_clients({ name = "lua_ls" })) do
    if client.initialized and allowed(client) then
      local active_buffers = {}
      for buf in pairs(client.attached_buffers) do
        if api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "lua" and vim.bo[buf].buftype == "" then
          active_buffers[#active_buffers + 1] = buf
        end
      end
      if #active_buffers > 0 then
        live[client.id] = true
        local nvim = require("lua_tools.nvim")
        local detected = nvim.matches(client, active_buffers, opts)
        local state = clients[client.id]
        if not state then
          state = { client = client, before = vim.deepcopy(client.settings.Lua), added = {} }
          clients[client.id] = state
        end
        local lua = vim.deepcopy(client.settings.Lua or {})
        lua.workspace = lua.workspace or {}
        local libraries, seen = {}, {}
        local function add(path, owned)
          if path and not seen[path] then
            seen[path], libraries[#libraries + 1] = true, path
            if owned then
              state.added[path] = true
            end
          end
        end
        for _, path in ipairs(lua.workspace.library or {}) do
          if not state.added[path] then
            add(path)
          end
        end
        state.added = {}
        state.nvim = detected
        add(vim.env.VIMRUNTIME .. "/lua", true)
        if detected then
          for _, path in ipairs(nvim.libraries(opts)) do
            add(path, true)
          end
        end
        for _, buf in ipairs(active_buffers) do
          for path in pairs(scan(buf)) do
            add(path, true)
          end
        end
        table.sort(libraries)
        lua = vim.tbl_deep_extend("keep", lua, defaults)
        lua.workspace.library = libraries
        state.applied = vim.deepcopy(lua)
        if not vim.deep_equal(client.settings.Lua, lua) then
          client.settings.Lua = lua
          notify(client)
        end
      end
    end
  end
  for id, state in pairs(clients) do
    if not live[id] then
      restore(state)
      clients[id] = nil
    end
  end
end
local function schedule()
  if not timer then
    timer = assert(vim.uv.new_timer())
  end
  local version = generation
  timer:start(
    opts.debounce or 80,
    0,
    vim.schedule_wrap(function()
      if group and generation == version then
        M.refresh()
      end
    end)
  )
end
function M.disable()
  configured = false
  generation = generation + 1
  if group then
    api.nvim_del_augroup_by_id(group)
    group = nil
  end
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  for _, state in pairs(clients) do
    restore(state)
  end
  clients, cache = {}, {}
  pcall(require("lua_tools.user_command").delete, "LuaTools")
end
function M.setup(config)
  require("lua_tools.config").validate(config or {})
  require("lua_tools.user_command").check("LuaTools")
  M.disable()
  opts = vim.deepcopy(config or {})
  configured = opts.enabled ~= false
  if not configured then
    return
  end
  -- Index and lexer stay unloaded until an attached LuaLS needs a library.
  local resolver = package.loaded["lua_tools.resolve"]
  if resolver then
    resolver.reset()
  end
  group = api.nvim_create_augroup("LuaTools", { clear = true })
  api.nvim_create_autocmd({
    "LspAttach",
    "LspDetach",
    "BufEnter",
    "TextChanged",
    "TextChangedI",
    "BufWritePost",
    "BufFilePost",
    "BufWipeout",
  }, {
    group = group,
    callback = function(ev)
      if ev.event == "BufWipeout" then
        cache[ev.buf] = nil
      end
      if vim.bo[ev.buf].filetype == "lua" or ev.event == "LspDetach" then
        schedule()
      end
    end,
  })
  api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "runtimepath",
    callback = function()
      cache = {}
      local loaded = package.loaded["lua_tools.resolve"]
      if loaded then
        loaded.reset()
      end
      schedule()
    end,
  })
  require("lua_tools.user_command").create("LuaTools", function(args)
    assert(args.args == "" or args.args == "refresh", "LuaTools accepts only refresh")
    M.refresh(true)
    if args.args ~= "refresh" then
      vim.notify(vim.inspect(M.info()), vim.log.levels.INFO, { title = "Lua workspace libraries", filetype = "lua" })
    end
  end, {
    nargs = "?",
    desc = "Inspect LuaLS libraries or refresh plugin discovery",
    complete = function()
      return { "refresh" }
    end,
  })
  M.refresh()
end
function M.info()
  local workspaces = {}
  for id, state in pairs(clients) do
    workspaces[#workspaces + 1] = {
      client = id,
      root = state.client.root_dir,
      nvim = state.nvim,
      library = vim.deepcopy(state.applied.workspace.library),
    }
  end
  table.sort(workspaces, function(a, b)
    return a.client < b.client
  end)
  return { enabled = configured, workspaces = workspaces }
end

return M

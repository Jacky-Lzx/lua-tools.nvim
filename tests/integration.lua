vim.opt.rtp:prepend(vim.env.LUA_TOOLS_ROOT or vim.fn.getcwd())
local api, uv = vim.api, vim.uv
local temp = assert(uv.fs_mkdtemp((vim.env.TMPDIR or "/tmp") .. "/lua-tools-lsp-XXXXXX"))
temp = assert(uv.fs_realpath(temp))
local clients = {}
local function run()
  local root, ordinary, checkout = temp .. "/config", temp .. "/project", temp .. "/cold,中文"
  for _, dir in ipairs({ root, ordinary, checkout .. "/lua" }) do
    vim.fn.mkdir(dir, "p")
  end
  local library = checkout .. "/lua/cold_library.lua"
  vim.fn.writefile({
    "---@class AutoIndexedOptions",
    "---@field color? string",
    "local M = {}",
    "---@return integer",
    "function M.answer() return 42 end",
    "return M",
  }, library)
  local function buffer(dir)
    local buf = api.nvim_create_buf(true, false)
    api.nvim_buf_set_name(buf, dir .. "/main.lua")
    api.nvim_buf_set_lines(buf, 0, -1, false, {
      "---@type AutoIndexedOptions",
      "local opts = {}",
      "print(opts.color)",
    })
    vim.bo[buf].filetype = "lua"
    return buf
  end
  local configbuf, plainbuf = buffer(root), buffer(ordinary)
  api.nvim_set_current_buf(configbuf)
  local tools = require("lua_tools")
  tools.setup({
    config_roots = { root },
    plugins = function()
      return { { dir = checkout } }
    end,
    debounce = 5,
  })
  local function start(buf, dir, suffix)
    local id = assert(vim.lsp.start({
      name = "lua_ls",
      cmd = {
        vim.env.LUA_LS or "lua-language-server",
        "--logpath=" .. temp .. "/logs-" .. suffix,
        "--metapath=" .. temp .. "/meta-" .. suffix,
      },
      root_dir = dir,
      settings = { Lua = { telemetry = { enable = false }, workspace = { checkThirdParty = false } } },
    }, { bufnr = buf }))
    local client = assert(vim.lsp.get_client_by_id(id))
    clients[#clients + 1] = client
    return client
  end
  local configclient, plainclient = start(configbuf, root, "config"), start(plainbuf, ordinary, "ordinary")
  assert(
    vim.wait(20000, function()
      return configclient.initialized
        and plainclient.initialized
        and vim.tbl_contains(
          vim.tbl_get(configclient.settings, "Lua", "workspace", "library") or {},
          checkout .. "/lua"
        )
    end, 20),
    "config LuaLS did not receive the cold plugin directory"
  )
  assert(
    not vim.tbl_contains(plainclient.settings.Lua.workspace.library or {}, checkout .. "/lua"),
    "ordinary client received config-only libraries"
  )
  local function completion(client, buf)
    local response = client:request_sync("textDocument/completion", {
      textDocument = { uri = vim.uri_from_bufnr(buf) },
      position = { line = 2, character = 11 },
      context = { triggerKind = 1 },
    }, 3000, buf)
    local result = response and response.result
    for _, item in ipairs(result and (result.items or result) or {}) do
      if item.label == "color" then
        return true
      end
    end
    return false
  end
  assert(
    vim.wait(15000, function()
      return completion(configclient, configbuf)
    end, 50),
    "LuaLS cannot complete a type from an unrequired plugin"
  )
  assert(not completion(plainclient, plainbuf), "unrelated Lua workspace sees config-only plugin types")
  local response
  assert(
    vim.wait(15000, function()
      response = configclient:request_sync("textDocument/definition", {
        textDocument = { uri = vim.uri_from_bufnr(configbuf) },
        position = { line = 2, character = 13 },
      }, 3000, configbuf)
      local result = response and response.result
      local location = result and (result[1] or result)
      return location and vim.uri_to_fname(location.uri or location.targetUri) == library
    end, 50),
    "LuaLS cannot navigate to automatically indexed LuaDoc: " .. vim.inspect(response)
  )
  -- Ordinary Lua projects retain the migrated, explicit module-discovery behavior.
  tools.setup({
    config_roots = { root },
    plugin_roots = { temp },
    plugins = function()
      return { { dir = checkout } }
    end,
    debounce = 5,
  })
  api.nvim_buf_set_lines(
    plainbuf,
    0,
    -1,
    false,
    { 'local lib = require("cold_library")', "local answer = lib.answer()", "print(answer)" }
  )
  api.nvim_exec_autocmds("TextChanged", { buffer = plainbuf })
  assert(
    vim.wait(10000, function()
      return vim.tbl_contains(plainclient.settings.Lua.workspace.library or {}, checkout .. "/lua")
    end, 20),
    "literal require did not discover a plugin in an ordinary Lua project"
  )
  assert(
    vim.wait(15000, function()
      local hover = plainclient:request_sync("textDocument/hover", {
        textDocument = { uri = vim.uri_from_bufnr(plainbuf) },
        position = { line = 1, character = 20 },
      }, 3000, plainbuf)
      return hover and hover.result and vim.inspect(hover.result):find("integer", 1, true) ~= nil
    end, 50),
    "LuaLS lost migrated plugin return types"
  )
  assert(
    not package.loaded.cold_library and not package.loaded.plugin_tools,
    "type discovery must not execute plugins or start a manager"
  )
  tools.dispose()
  assert(
    not vim.tbl_contains(configclient.settings.Lua.workspace.library or {}, checkout .. "/lua"),
    "dispose did not restore LuaLS libraries"
  )
  api.nvim_buf_delete(configbuf, { force = true })
  api.nvim_buf_delete(plainbuf, { force = true })
end
local ok, err = xpcall(run, debug.traceback)
for _, client in ipairs(clients) do
  client:stop(true)
end
vim.wait(5000, function()
  return #vim.lsp.get_clients() == 0
end, 20)
local message = ok
    and "PASS actual LuaLS: automatic LuaDoc completion and definition, ordinary-project isolation, demand discovery and disposal"
  or tostring(err) .. "\nArtifacts: " .. temp
if ok then
  vim.fn.delete(temp, "rf")
end
if vim.env.LUA_TOOLS_TEST_TMP then
  vim.fn.writefile(vim.split(message, "\n"), vim.env.LUA_TOOLS_TEST_TMP .. "/result")
end
print(message)
vim.cmd(ok and "qa!" or "cquit 1")

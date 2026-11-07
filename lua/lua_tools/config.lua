local M = {}
local function strings(value, field)
  assert(type(value) == "table" and vim.islist(value), field .. " must be a list")
  for _, item in ipairs(value) do
    assert(type(item) == "string" and item ~= "", field .. " must contain nonempty strings")
  end
end
function M.validate(opts)
  assert(opts.nvim == nil or type(opts.nvim) == "boolean", "lua-tools.nvim must be boolean")
  assert(opts.plugins == nil or type(opts.plugins) == "function", "lua-tools.plugins must be a function")
  if opts.config_roots ~= nil then
    strings(opts.config_roots, "lua-tools.config_roots")
  end
  assert(
    opts.enabled == nil or type(opts.enabled) == "boolean" or type(opts.enabled) == "function",
    "lua-tools.enabled must be boolean or function"
  )
  for _, key in ipairs({ "debounce", "max_bytes" }) do
    assert(
      opts[key] == nil or type(opts[key]) == "number" and opts[key] >= 0 and opts[key] < math.huge,
      "lua-tools." .. key .. " must be nonnegative"
    )
  end
  if opts.plugin_roots ~= nil then
    strings(opts.plugin_roots, "lua-tools.plugin_roots")
  end
  if opts.library ~= nil then
    assert(type(opts.library) == "table" and vim.islist(opts.library), "lua-tools.library must be a list")
    for _, item in ipairs(opts.library) do
      assert(
        type(item) == "string" or type(item) == "table" and type(item.path) == "string",
        "lua-tools.library needs a path"
      )
      assert((type(item) == "string" and item or item.path) ~= "", "lua-tools.library path must not be empty")
      if type(item) == "table" then
        for _, key in ipairs({ "words", "mods", "files" }) do
          if item[key] then
            strings(item[key], "lua-tools.library." .. key)
            for _, pattern in ipairs(item[key]) do
              assert(pcall(string.find, "", pattern), "invalid lua-tools.library pattern")
            end
          end
        end
      end
    end
  end
end
return M

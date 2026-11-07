local M = {}
function M.check()
  vim.health.start("lua-tools.nvim")
  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim 0.11+")
  else
    vim.health.error("Neovim 0.11+ is required")
  end
  if vim.fn.executable("lua-language-server") == 0 then
    vim.health.warn(
      "lua-language-server is not on PATH",
      { "Configure LuaLS separately; :LuaTools shows indexed clients" }
    )
  end
end
return M

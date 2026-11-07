local M = {}

function M.normalize(path)
  path = vim.fs.normalize(vim.fn.expand(path))
  if not path:match("^/") and not path:match("^%a:[/\\]") then
    path = vim.fs.joinpath(assert(vim.uv.cwd()), path)
  end
  local ancestor = path
  while ancestor do
    local real = vim.uv.fs_realpath(ancestor)
    if real then
      return vim.fs.normalize(real .. path:sub(#ancestor + 1))
    end
    local parent = vim.fs.dirname(ancestor)
    ancestor = parent ~= ancestor and parent or nil
  end
  return path
end

function M.contains(root, path)
  root, path = M.normalize(root), M.normalize(path)
  return root == path or vim.startswith(path, root:gsub("/$", "") .. "/")
end

-- vim.opt.runtimepath:get() splits escaped commas in plugin paths.
function M.runtime()
  local paths, part, escaped = {}, "", false
  for char in vim.o.runtimepath:gmatch(".") do
    if escaped then
      part, escaped = part .. char, false
    elseif char == "\\" then
      escaped = true
    elseif char == "," then
      paths[#paths + 1], part = part, ""
    else
      part = part .. char
    end
  end
  if escaped then
    part = part .. "\\"
  end
  paths[#paths + 1] = part
  return paths
end

return M

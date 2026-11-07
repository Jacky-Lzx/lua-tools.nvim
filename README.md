# lua-tools.nvim

LuaLS libraries for Neovim configuration and Lua development.

## Features

- Detect Neovim configuration and index selected plugins, including cold and local checkouts.
- Discover additional libraries from literal `require()` calls, `---@module` annotations and rules.
- Keep libraries isolated per LuaLS client and restore owned settings on disposal.

## Requirements

Neovim **0.11+** and a separately configured `lua-language-server` (`lua_ls`).
This plugin does not install or start language servers.

## Installation

With plugin-tools.nvim:

```lua
{
  id = "lua-tools.nvim",
  source = "Jacky-Lzx/lua-tools.nvim",
  main = "lua_tools",
  opts = {},
}
```

Or add the checkout to `runtimepath`, then configure it directly:

```lua
require("lua_tools").setup({})
```

## Usage

Open a Lua file in your Neovim configuration. The plugin adds selected plugin
`lua/` directories to that client's `Lua.workspace.library`; their LuaDoc types
become available even without module references:

```lua
---@type plugin_tools.BootstrapOptions
local opts = { auto_install = true, specs = {} }
return opts
```

`:LuaTools` shows client roots and libraries. `:LuaTools refresh` rescans checkouts.
Set `nvim = false` to disable automatic indexing of all selected plugins while
keeping module-based discovery.

## Documentation

- [Complete reference](doc/lua-tools.txt) — `:help lua-tools`.
- [Configuration and lifecycle](doc/guide.md).
- Diagnose availability with `:checkhealth lua_tools`.

## Development

```sh
python3 tests/run.py default
python3 tests/run.py integration,ui
```

The second command requires `lua-language-server` on PATH and tests actual LuaLS
completion, definition lookup and project isolation, headless and in a real PTY.
See [the test workflow](tests/README.md) for retained failure evidence.

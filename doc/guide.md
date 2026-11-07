# Configuration and lifecycle

## Options

```lua
---@type lua_tools.Options
local opts = {
  nvim = true,
  config_roots = { "~/src/my-nvim-config" },
  debounce = 80,
  max_bytes = 1024 * 1024,
  plugin_roots = { "~/src/neovim-plugins" },
  library = {
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    { path = "extra-plugin.nvim", mods = { "extra_plugin" } },
  },
}
require("lua_tools").setup(opts)
```

`config_roots` extends `stdpath('config')` and the directory of `$MYVIMRC` when
it names `init.lua`. Real paths, including parents of new unsaved files, handle
symlinks. A client matches when its root or an attached Lua file is inside a
configuration root. Ordinary projects keep module-based discovery; they do not
receive the configuration's full plugin set. Libraries are per client: buffers
sharing one LuaLS client share that client's libraries.

For matching configuration clients, the default provider reads `status()` from
an already loaded plugin-tools manager. It never loads or starts a manager.
It combines actual selected directories with available runtimepath roots,
including a manually loaded manager without its own spec, `dir`, dev checkouts
and on-demand components. Missing/inactive declarations are excluded. The
configuration's own source root remains workspace code rather than a library. Provide `plugins` to use an isolated manager
or another package manager:

```lua
require("lua_tools").setup({
  plugins = function()
    return manager:status() -- list of { dir = '/actual/checkout', ... }
  end,
})
```

The callback runs only for a detected configuration client and must return a
list or nil (runtimepath fallback). Only existing `<dir>/lua` directories are
added, with canonical-path deduplication. No checkout is mounted or executed.

`plugin_roots` supplies candidate directories for module-based discovery.
Defaults are `stdpath('data')/plugin-tools` and `stdpath('data')/lazy`; runtimepath
and already available lazy.nvim declarations are also searched. This candidate
search does not add every installed plugin to ordinary Lua projects. Literal
`require()` calls and `---@module` references select the libraries they need.

A `library` string is unconditional. Table rules match Lua-pattern `words`/`files`
or literal `mods` prefixes. `${3rd}` is expanded by LuaLS. Buffers above `max_bytes`
skip lexical scanning; configured-plugin directory indexing remains available.
LuaLS's own preload limits still apply to the resulting library list.

## Lifecycle

Requiring `lua_tools` has no side effects. `setup()` validates and copies options,
then registers lightweight listeners and the owned `:LuaTools` command. Indexing
and scanning load only when an initialized `lua_ls` has attached Lua file buffers.
Repeated setup replaces this plugin's previous configuration. `enabled = false`
disposes it; `dispose()` is idempotent. `refresh()` after disposal does not enable it.

Refreshes are debounced on attachment, buffer edits/renames/entry, writes, wipeout
and runtimepath changes. Unchanged settings do not notify LuaLS. Explicit refresh
invalidates path and text caches, including newly installed plugin directories.
`info()` returns copied `{ enabled, workspaces }` data.

Existing user libraries and settings are preserved. Supplied defaults fill missing
values: LuaJIT runtime, Neovim-compatible require paths and third-party checking
disabled. Disposal restores only owned additions/defaults and preserves external
changes. Project `.luarc.json`/`.luarc.jsonc` files are respected by default.
`enabled = true` explicitly supplements these clients; an `enabled(root)` predicate
can choose clients. Project files are never rewritten; LuaLS configuration-file
precedence still applies.

## Migrating from lsp-tools.nvim

Move the former `lua = { ... }` table to `require('lua_tools').setup({ ... })` or
this plugin's declaration `opts`. Remove the old `lua` option from lsp-tools.
Use `:LuaTools` in place of `:LspToolsLua`. Server configuration remains in
lsp-tools or Neovim's native LSP configuration.

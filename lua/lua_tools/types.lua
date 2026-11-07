---@meta

---@class lua_tools.Library
---@field path string Absolute directory, plugin name or ${3rd} library path.
---@field words? string[] Lua patterns matched against buffer text.
---@field mods? string[] Literal module prefixes found in require()/@module references.
---@field files? string[] Lua patterns matched against the buffer filename.

---@class lua_tools.Plugin
---@field dir string Actual checkout or component directory, including dev/external paths.
---@field selected? boolean False excludes inactive declarations.
---@field state? {phase?: string} A missing plugin is excluded.

---@class lua_tools.Options
---@field enabled? boolean|fun(root: string): boolean Default: skip projects with .luarc.json/jsonc; true opts in.
---@field nvim? boolean Index selected plugin lua/ directories in Neovim config workspaces (default true).
---@field config_roots? string[] Additional Neovim configuration roots; real paths are compared.
---@field plugins? fun(): lua_tools.Plugin[]? Provide selected plugin directories; default uses an already loaded plugin_tools manager; runtimepath libraries are also included.
---@field plugin_roots? string[] Parent checkout directories for module discovery; default data/plugin-tools and data/lazy.
---@field library? (string|lua_tools.Library)[] Additional unconditional or conditional libraries.
---@field debounce? number Library refresh delay in milliseconds (default 80).
---@field max_bytes? number Maximum bytes per buffer for lexical scanning (default 1048576).

---@class lua_tools.Workspace
---@field client integer
---@field root? string
---@field nvim boolean Whether this client is editing a detected Neovim configuration.
---@field library string[] Current augmented LuaLS libraries.

---@class lua_tools.Info
---@field enabled boolean
---@field workspaces lua_tools.Workspace[]

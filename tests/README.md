# Testing

`python3 tests/run.py default` runs offline unit, setup, documentation, runner and
format checks. Python 3.9+, Neovim and StyLua are required. Use `--list`, `--check`,
`--filter`, `--keep` or `--output /tmp/new-directory` to inspect registrations and
retain artifacts. `NVIM_BIN` selects Neovim.

`python3 tests/run.py integration,ui` additionally requires `lua-language-server`
on PATH. It checks actual automatic LuaDoc completion and definition lookup,
ordinary-project isolation, module-based discovery and settings restoration.
The UI case runs in a real PTY and requires a Unix platform. No downloads occur.

Every case receives isolated XDG/TMP state and a bounded lifetime. Failures retain
per-case output and summary.json. LuaLS failures retain server logs; terminal
failures retain terminal.log. Unit fixtures create private fake clients and source
files whose execution would fail, verifying that indexing remains read-only.

The runner and documentation checker are vendored from plugin-tools.nvim.

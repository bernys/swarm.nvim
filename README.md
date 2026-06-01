# swarm.nvim

## Features

| Feature | Description |
|---|---|
| **Add cursor below / above** | `<C-Down>` / `<C-Up>` |
| **Add cursor at next match** | `<C-n>` — like VM's `<C-n>` |
| **Remove last cursor** | `<C-p>` |
| **Skip current match** | `<C-x>` |
| **Select all occurrences** | `<leader>A` |
| **Cursors on visual lines** | `<C-m>` in visual mode |
| **Exit** | `<Esc>` |
| **User commands** | `:MCAddDown`, `:MCAddUp`, `:MCAddWord`, `:MCSelectAll`, `:MCAddVisual`, `:MCRemoveLast`, `:MCSkip`, `:MCCancel` |

All extra cursors are rendered with extmarks and follow buffer edits automatically.
Typing in insert mode, backspace, and enter are replayed on every cursor.

---

## Requirements

- **Neovim ≥ 0.9** (uses `vim.on_key`, `nvim_buf_set_extmark`, `nvim_set_hl`)

---

## Installation

### lazy.nvim

```lua
{
  "bernys/swarm.nvim",
  event = "VeryLazy",
  config = function()
    require("swarm").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "bernys/swarm.nvim",
  config = function()
    require("swarm").setup()
  end,
}
```

---

## Configuration

```lua
require("swarm").setup({
  -- Set to false to define your own keymaps
  default_mappings = true,

  -- Highlight group for virtual cursors
  highlight_cursor = "Swarm",

  -- Highlight group for virtual selections
  highlight_visual = "SwarmVisual",
})
```

### Custom keymaps

```lua
require("swarm").setup({ default_mappings = false })

local s   = require("swarm")
local opts = { noremap = true, silent = true }

vim.keymap.set({ "n", "x" }, "<C-n>",     s.add_cursor_word,    opts)
vim.keymap.set({ "n", "x" }, "<C-p>",     s.remove_last_cursor, opts)
vim.keymap.set({ "n", "x" }, "<C-x>",     s.skip_cursor,        opts)
vim.keymap.set({ "n", "x" }, "<C-Down>",  function() s.add_cursor("down") end, opts)
vim.keymap.set({ "n", "x" }, "<C-Up>",    function() s.add_cursor("up") end,   opts)
vim.keymap.set({ "n", "x" }, "<leader>A", s.select_all_word,    opts)
vim.keymap.set("x",          "<C-m>",     s.add_cursors_visual,  opts)
vim.keymap.set("n",          "<Esc>",     s.cancel,             opts)
```

---

## Workflow examples

### Edit every occurrence of a word

1. Place the cursor on the word.
2. Press `<C-n>` once — the current word is selected and cursor jumps to the next match.
3. Keep pressing `<C-n>` to add more cursors.
4. Press `<leader>A` to select **all** occurrences at once.
5. Enter insert mode and type; all cursors edit simultaneously.
6. Press `<Esc>` to finish.

### Edit every line in a visual block

1. Select lines with `V` (linewise visual).
2. Press `<C-m>` — a cursor is placed at the same column on every selected line.
3. Type your edits.
4. Press `<Esc>` to finish.

---

## Architecture

```
plugin/swarm.lua   ← Neovim plugin entry point, default keymaps
lua/swarm/
  init.lua               ← Public API (add_cursor, cancel, …)
  config.lua             ← User configuration
  state.lua              ← Virtual cursor list + extmark management
  utils.lua              ← Buffer helpers (find occurrences, insert/delete)
  input.lua              ← on_key capture, keystroke replay to cursors
  highlight.lua          ← Default highlight groups
```

---

## Highlight groups

| Group | Default | Usage |
|---|---|---|
| `Swarm` | purple block | Virtual cursor positions |
| `SwarmVisual` | subtle bg | Virtual visual selections |
| `SwarmMain` | cyan block | Real cursor while 'Swarm' is active |

Override in your colorscheme or after `setup()`:

```lua
vim.api.nvim_set_hl(0, "Swarm", { bg = "#ff0000", fg = "#ffffff", bold = true })
```

---

## Contributing

PRs welcome! Areas to improve:

- Visual-mode selections on virtual cursors
- Per-cursor registers/yanks
- Regex-based `:MCFind` command
- Dot-repeat (`.`) support
- Undo grouping across all cursors

---

## License

MIT

-- swarm.nvim
-- Plugin entry point

if vim.g.loaded_swarm then
  return
end
vim.g.loaded_swarm = true

-- Require the main module
local s = require("swarm")

-- Default keymaps (can be disabled with setup({ default_mappings = false }))
local function setup_default_mappings()
  local opts = { noremap = true, silent = true }

  -- Add cursor below / above
  vim.keymap.set({ "n", "x" }, "<C-Down>",  function() s.add_cursor("down") end,   opts)
  vim.keymap.set({ "n", "x" }, "<C-Up>",    function() s.add_cursor("up") end,     opts)

  -- Add cursor at next/prev match of word under cursor 
  vim.keymap.set({ "n", "x" }, "<C-n>",     function() s.add_cursor_word() end,    opts)
  vim.keymap.set({ "n", "x" }, "<C-p>",     function() s.remove_last_cursor() end, opts)
  vim.keymap.set({ "n", "x" }, "<C-x>",     function() s.skip_cursor() end,        opts)

  -- Select all occurrences of word under cursor
  vim.keymap.set({ "n", "x" }, "<leader>A", function() s.select_all_word() end,    opts)

  -- Add cursors at every line of visual selection
  vim.keymap.set("x",          "<C-m>",     function() s.add_cursors_visual() end, opts)

  -- ESC to exit swarm mode
  vim.keymap.set("n",          "<Esc>",     function() s.cancel() end,             opts)
end

-- Auto-setup with defaults when plugin loads
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local cfg = require("swarm.config").get()
    if cfg.default_mappings then
      setup_default_mappings()
    end
  end,
  once = true,
})

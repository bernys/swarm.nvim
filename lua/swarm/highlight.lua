-- swarm.nvim – highlight module
local M = {}

function M.setup()
  -- Main cursor highlight (block style, distinct colour)
  vim.api.nvim_set_hl(0, "Swarm", {
    default = true,
    fg      = "#1e1e2e",
    bg      = "#cba6f7",
    bold    = true,
  })

  -- Visual-selection highlight for extra cursors
  vim.api.nvim_set_hl(0, "SwarmVisual", {
    default = true,
    bg      = "#45475a",
  })

  -- Main-cursor indicator (the "real" cursor when swarm is active)
  vim.api.nvim_set_hl(0, "SwarmMain", {
    default = true,
    fg      = "#1e1e2e",
    bg      = "#89dceb",
    bold    = true,
  })
end

return M

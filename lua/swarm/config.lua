-- swarm.nvim – config module
local M = {}

---@class MCConfig
---@field default_mappings boolean
---@field highlight_cursor string  highlight group for extra cursors
---@field highlight_visual string  highlight group for extra visual selections
---@field signs boolean            show signs in the sign column
local defaults = {
  default_mappings   = true,
  highlight_cursor   = "Swarm",
  highlight_visual   = "SwarmVisual",
  signs              = false,
}

local current = vim.deepcopy(defaults)

---Apply user config on top of defaults.
---@param opts? MCConfig
function M.setup(opts)
  current = vim.tbl_deep_extend("force", defaults, opts or {})
end

---Return the active config table.
---@return MCConfig
function M.get()
  return current
end

return M

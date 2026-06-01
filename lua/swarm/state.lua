-- swarm.nvim – state module
-- Holds all virtual-cursor data and the namespace used for extmarks.

local M = {}

---@class VirtualCursor
---@field id       integer   extmark id (used to track position after edits)
---@field row      integer   0-based row
---@field col      integer   0-based byte column
---@field v_row    integer   visual-start row   (same as row when not in visual)
---@field v_col    integer   visual-start col
---@field visual   boolean   cursor has a visual selection
---@field register table     per-cursor register snapshot  { [reg] = text }

-- Neovim namespace for all our extmarks
M.ns = vim.api.nvim_create_namespace("swarm")

-- List of active virtual cursors (the "real" cursor is NOT in this list)
---@type VirtualCursor[]
M.cursors = {}

-- Whether swarm mode is currently active
M.active = false

-- The buffer we're operating in
M.bufnr = nil

---Create a new virtual-cursor record.
---@param row integer 0-based
---@param col integer 0-based
---@return VirtualCursor
function M.new_cursor(row, col)
  local bufnr = vim.api.nvim_get_current_buf()
  local id = vim.api.nvim_buf_set_extmark(bufnr, M.ns, row, col, {
    hl_group      = "Swarm",
    hl_mode       = "combine",
    end_col       = col + 1,  -- highlight one character
    priority      = 200,
  })
  ---@type VirtualCursor
  return {
    id       = id,
    row      = row,
    col      = col,
    v_row    = row,
    v_col    = col,
    visual   = false,
    register = {},
  }
end

---Sync cursor row/col from extmark (buffers can shift after edits).
---@param cursor VirtualCursor
function M.sync_cursor(cursor)
  local bufnr = M.bufnr or vim.api.nvim_get_current_buf()
  local pos   = vim.api.nvim_buf_get_extmark_by_id(bufnr, M.ns, cursor.id, {})
  if pos and #pos >= 2 then
    cursor.row = pos[1]
    cursor.col = pos[2]
  end
end

---Remove a virtual cursor and its extmarks.
---@param cursor VirtualCursor
function M.remove_cursor(cursor)
  local bufnr = M.bufnr or vim.api.nvim_get_current_buf()
  pcall(vim.api.nvim_buf_del_extmark, bufnr, M.ns, cursor.id)
end

---Clear all virtual cursors and reset state.
function M.clear()
  local bufnr = M.bufnr or vim.api.nvim_get_current_buf()
  for _, c in ipairs(M.cursors) do
    pcall(vim.api.nvim_buf_del_extmark, bufnr, M.ns, c.id)
  end
  M.cursors = {}
  M.active  = false
  M.bufnr   = nil
end

---Check if a position (row, col) already has a virtual cursor.
---@param row integer
---@param col integer
---@return boolean
function M.has_cursor_at(row, col)
  for _, c in ipairs(M.cursors) do
    if c.row == row and c.col == col then
      return true
    end
  end
  return false
end

return M

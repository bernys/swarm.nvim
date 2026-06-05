-- swarm.nvim – cursor utilities
local state = require("swarm.state")
local M     = {}

---Get the word under the real cursor (same logic as <cword>).
---@return string
function M.get_cword()
  return vim.fn.expand("<cword>")
end

---Escape a string for use in a Lua pattern (not vim regex).
---@param s string
---@return string
function M.lua_escape(s)
  return (s:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"))
end

---Escape a string for use as a Vim \V (very-no-magic) pattern.
---@param s string
---@return string
function M.vim_escape(s)
  return vim.fn.escape(s, "\\/")
end

---Return (row, col) of the real cursor (0-based).
---@return integer, integer
function M.real_cursor_pos()
  local pos = vim.api.nvim_win_get_cursor(0)
  return pos[1] - 1, pos[2]
end

---Move the real cursor to (row, col) — 0-based.
---@param row integer
---@param col integer
function M.set_real_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---Get the line text at a given 0-based row.
---@param row integer
---@param bufnr? integer
---@return string
function M.get_line(row, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
  return lines[1] or ""
end

---Return all positions (0-based {row,col}) of `pattern` in the buffer.
---Pattern is a Lua plain string (not a regex).
---@param word   string
---@param bufnr? integer
---@return { row: integer, col: integer }[]
function M.find_all_occurrences(word, bufnr)
  bufnr         = bufnr or vim.api.nvim_get_current_buf()
  local lines   = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local pattern = M.lua_escape(word)
  local results = {}
  for row, line in ipairs(lines) do
    local col = 1
    while true do
      local s, e = line:find(pattern, col, false)
      if not s then break end
      -- Make sure this is a whole-word match
      local before = s > 1 and line:sub(s - 1, s - 1) or " "
      local after  = e < #line and line:sub(e + 1, e + 1) or " "
      local wb     = not before:match("%w")
      local we     = not after:match("%w")
      if wb and we then
        table.insert(results, { row = row - 1, col = s - 1 })
      end
      col = e + 1
    end
  end
  return results
end

---Find the *next* occurrence of `word` starting after (from_row, from_col).
---Wraps around the buffer.
---@param word     string
---@param from_row integer 0-based
---@param from_col integer 0-based
---@param bufnr?   integer
---@return { row: integer, col: integer }|nil
function M.find_next_occurrence(word, from_row, from_col, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local all = M.find_all_occurrences(word, bufnr)
  if #all == 0 then return nil end

  -- Find first occurrence after cursor
  for _, pos in ipairs(all) do
    if pos.row > from_row or (pos.row == from_row and pos.col > from_col) then
      return pos
    end
  end
  -- Wrap: return the very first
  return all[1]
end

---Find the *previous* occurrence of `word` starting before (from_row, from_col).
---Wraps around the buffer.
---@param word     string
---@param from_row integer 0-based
---@param from_col integer 0-based
---@param bufnr?   integer
---@return { row: integer, col: integer }|nil
function M.find_prev_occurrence(word, from_row, from_col, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local all = M.find_all_occurrences(word, bufnr)
  if #all == 0 then return nil end

  -- Find first occurrence before cursor (iterate backwards)
  for i = #all, 1, -1 do
    local pos = all[i]
    if pos.row < from_row or (pos.row == from_row and pos.col < from_col) then
      return pos
    end
  end
  -- Wrap: return the very last
  return all[#all]
end

---Replay a normal-mode command string on the real cursor.
---This is used to mirror keystrokes to virtual cursors.
---@param cmd string
function M.exec_normal(cmd)
  vim.cmd("normal! " .. cmd)
end

---Insert text at a buffer position, returning the new column.
---@param bufnr  integer
---@param row    integer 0-based
---@param col    integer 0-based
---@param text   string
---@return integer new_col
function M.insert_at(bufnr, row, col, text)
  local line     = M.get_line(row, bufnr)
  local new_line = line:sub(1, col) .. text .. line:sub(col + 1)
  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
  return col + #text
end

---Delete `count` bytes at position (row, col).
---@param bufnr  integer
---@param row    integer 0-based
---@param col    integer 0-based
---@param count  integer
function M.delete_at(bufnr, row, col, count)
  local line     = M.get_line(row, bufnr)
  local new_line = line:sub(1, col) .. line:sub(col + count + 1)
  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
end

return M

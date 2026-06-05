-- swarm.nvim – public API
local config    = require("swarm.config")
local highlight = require("swarm.highlight")
local state     = require("swarm.state")
local utils     = require("swarm.utils")
local input     = require("swarm.input")

local M         = {}

-- ─── Internal helpers ─────────────────────────────────────────────────────────

---Activate swarm mode if not already active.
local function ensure_active()
  if not state.active then
    state.active = true
    state.bufnr  = vim.api.nvim_get_current_buf()
    input.attach()
    input.start_key_capture()
    -- Highlight the real cursor distinctly
    vim.api.nvim_set_hl(0, "Cursor", { link = "SwarmMain" })
    vim.notify("[swarm] active – Esc to exit", vim.log.levels.INFO, { title = "swarm.nvim" })
  end
end

---Deactivate swarm mode.
local function deactivate()
  state.clear()
  input.stop_key_capture()
  -- Restore normal Cursor highlight
  vim.api.nvim_set_hl(0, "Cursor", {})
  vim.notify("[swarm] exited", vim.log.levels.INFO, { title = "swarm.nvim" })
end

-- ─── Public commands ──────────────────────────────────────────────────────────

---Add a cursor one line above or below the current cursor.
---@param dir "up"|"down"
function M.add_cursor(dir)
  local row, col = utils.real_cursor_pos()
  local new_row  = dir == "down" and row + 1 or row - 1
  local line_cnt = vim.api.nvim_buf_line_count(0)

  if new_row < 0 or new_row >= line_cnt then return end

  local line    = utils.get_line(new_row)
  local new_col = math.min(col, #line > 0 and #line - 1 or 0)

  if state.has_cursor_at(new_row, new_col) then return end

  ensure_active()
  local cursor = state.new_cursor(new_row, new_col)
  table.insert(state.cursors, cursor)

  -- Move real cursor in the direction
  utils.set_real_cursor(new_row, new_col)
end

---Add a cursor at the next occurrence of the word under the cursor.
---If called for the first time, places a cursor at the current word too.
function M.add_cursor_word()
  local word = utils.get_cword()
  if word == "" then return end

  local row, col = utils.real_cursor_pos()

  -- Find the start of the current word
  local line = utils.get_line(row)
  local w_start = col
  while w_start > 0 and line:sub(w_start, w_start):match("%w") do
    w_start = w_start - 1
  end
  if not line:sub(w_start + 1, w_start + 1):match("%w") then
    w_start = w_start + 1
  end

  -- Initialize swarm mode if not active and add the first virtual cursor
  if not state.active then
    ensure_active()
    utils.set_real_cursor(row, w_start)

    if not state.has_cursor_at(row, w_start) then
      local c = state.new_cursor(row, w_start)
      table.insert(state.cursors, c)
    end
    return
  end

  -- Ensure the current position has a virtual cursor before jumping
  if not state.has_cursor_at(row, w_start) then
    local c = state.new_cursor(row, w_start)
    table.insert(state.cursors, c)
  end

  -- Find the next occurrence
  local next_pos = utils.find_next_occurrence(word, row, col)
  if not next_pos then
    vim.notify("[swarm] No more occurrences of '" .. word .. "'", vim.log.levels.WARN)
    return
  end

  -- Avoid infinite loops if the next position already has a virtual cursor
  local max_attempts = 100
  while next_pos and state.has_cursor_at(next_pos.row, next_pos.col) and max_attempts > 0 do
    next_pos = utils.find_next_occurrence(word, next_pos.row, next_pos.col)
    max_attempts = max_attempts - 1
  end

  -- Move the real cursor to the next occurrence and add a new virtual cursor immediately
  if next_pos and not state.has_cursor_at(next_pos.row, next_pos.col) then
    utils.set_real_cursor(next_pos.row, next_pos.col)

    local c = state.new_cursor(next_pos.row, next_pos.col)
    table.insert(state.cursors, c)
  end
end

---Select ALL occurrences of the word under the cursor at once.
function M.select_all_word()
  local word = utils.get_cword()
  if word == "" then return end

  state.clear()
  local all = utils.find_all_occurrences(word, vim.api.nvim_get_current_buf())
  if #all == 0 then return end

  ensure_active()

  for i, pos in ipairs(all) do
    if i == #all then
      -- Last occurrence becomes the real cursor
      utils.set_real_cursor(pos.row, pos.col)
    else
      local c = state.new_cursor(pos.row, pos.col)
      table.insert(state.cursors, c)
    end
  end

  vim.notify(
    string.format("[swarm] %d cursors on '%s'", #all, word),
    vim.log.levels.INFO
  )
end

function M.change_word()
  if not state.active then return end

  input.replay_normal("ce")

  local keys = vim.api.nvim_replace_termcodes("ce", true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
end

---Add a cursor at every line within the current visual selection.
function M.add_cursors_visual()
  -- Get visual selection bounds
  local v_start = vim.fn.getpos("'<")
  local v_end   = vim.fn.getpos("'>")
  local row1    = v_start[2] - 1 -- 0-based
  local row2    = v_end[2] - 1
  local col     = v_start[3] - 1

  -- Exit visual mode first
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

  if row1 == row2 then return end

  state.clear()
  ensure_active()

  for row = row1, row2 do
    local line     = utils.get_line(row)
    local safe_col = math.min(col, #line > 0 and #line - 1 or 0)
    if row == row2 then
      utils.set_real_cursor(row, safe_col)
    else
      local c = state.new_cursor(row, safe_col)
      table.insert(state.cursors, c)
    end
  end

  vim.notify(
    string.format("[swarm] %d cursors added", row2 - row1 + 1),
    vim.log.levels.INFO
  )
end

---Remove the most recently added virtual cursor (undo last <C-n>).
function M.remove_last_cursor()
  if not state.active or #state.cursors == 0 then return end
  local last = table.remove(state.cursors)
  state.remove_cursor(last)
  if #state.cursors == 0 then
    deactivate()
  end
end

---Skip the current match and jump to the next one.
function M.skip_cursor()
  if not state.active or #state.cursors == 0 then return end
  -- Remove the cursor that corresponds to where the real cursor is now
  M.remove_last_cursor()
  -- And advance to the next match
  M.add_cursor_word()
end

---Execute a normal-mode command on all cursors.
---@param cmd string
function M.run_normal(cmd)
  if not state.active then return end
  input.replay_normal(cmd)
end

---Cancel swarm mode and return to normal editing.
function M.cancel()
  if state.active then
    deactivate()
  end
end

-- ─── Setup ────────────────────────────────────────────────────────────────────

---Configure the plugin. Call from your init.lua.
---@param opts? MCConfig
function M.setup(opts)
  config.setup(opts)
  highlight.setup()

  -- User commands
  vim.api.nvim_create_user_command("MCAddDown", function() M.add_cursor("down") end, {})
  vim.api.nvim_create_user_command("MCAddUp", function() M.add_cursor("up") end, {})
  vim.api.nvim_create_user_command("MCAddWord", function() M.add_cursor_word() end, {})
  vim.api.nvim_create_user_command("MCSelectAll", function() M.select_all_word() end, {})
  vim.api.nvim_create_user_command("MCAddVisual", function() M.add_cursors_visual() end, {})
  vim.api.nvim_create_user_command("MCRemoveLast", function() M.remove_last_cursor() end, {})
  vim.api.nvim_create_user_command("MCSkip", function() M.skip_cursor() end, {})
  vim.api.nvim_create_user_command("MCCancel", function() M.cancel() end, {})
end

return M

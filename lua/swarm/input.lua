-- swarm.nvim – input handler
-- Intercepts keystrokes while swarm is active and replays them
-- on every virtual cursor after executing on the real cursor.

local state = require("swarm.state")
local utils = require("swarm.utils")
local M     = {}

-- Keys we handle specially (not replayed verbatim as insert text)
local SPECIAL = {
  ["<BS>"]    = true, ["<Del>"] = true,
  ["<Left>"]  = true, ["<Right>"] = true,
  ["<Up>"]    = true, ["<Down>"]  = true,
  ["<Home>"]  = true, ["<End>"]   = true,
  ["<CR>"]    = true, ["<Esc>"]   = true,
}

-- Current insert-mode text being accumulated
local insert_buf = ""

-- Are we currently in insert mode?
local in_insert = false

---Apply a single normal-mode command to all virtual cursors.
---Saves and restores the real cursor between each virtual cursor execution.
---@param cmd string   vim normal! command
local function replay_normal(cmd)
  if #state.cursors == 0 then return end

  local real_row, real_col = utils.real_cursor_pos()
  local bufnr              = vim.api.nvim_get_current_buf()

  for _, cursor in ipairs(state.cursors) do
    -- Sync position from extmark (buffer may have shifted)
    state.sync_cursor(cursor)
    -- Move real cursor to virtual position
    utils.set_real_cursor(cursor.row, cursor.col)
    -- Execute the command
    vim.cmd("silent! normal! " .. cmd)
    -- Store new position back into virtual cursor
    cursor.row, cursor.col = utils.real_cursor_pos()
  end

  -- Restore real cursor
  utils.set_real_cursor(real_row, real_col)
end

---Apply insert-mode text to all virtual cursors at once.
---@param text string
local function replay_insert(text)
  if #state.cursors == 0 or text == "" then return end

  local real_row, real_col = utils.real_cursor_pos()
  local bufnr              = vim.api.nvim_get_current_buf()

  -- We insert in reverse row order so earlier extmarks are not shifted
  -- by later insertions. Sort descending.
  local sorted = vim.deepcopy(state.cursors)
  table.sort(sorted, function(a, b)
    if a.row ~= b.row then return a.row > b.row end
    return a.col > b.col
  end)

  for _, cursor in ipairs(sorted) do
    state.sync_cursor(cursor)
    local new_col = utils.insert_at(bufnr, cursor.row, cursor.col, text)
    cursor.col = new_col
  end

  -- Also shift the real cursor col if on the same row as any virtual cursor
  utils.set_real_cursor(real_row, real_col)
end

---Apply a backspace to all virtual cursors.
local function replay_backspace()
  if #state.cursors == 0 then return end

  local real_row, real_col = utils.real_cursor_pos()
  local bufnr              = vim.api.nvim_get_current_buf()

  for _, cursor in ipairs(state.cursors) do
    state.sync_cursor(cursor)
    if cursor.col > 0 then
      utils.delete_at(bufnr, cursor.row, cursor.col - 1, 1)
      cursor.col = cursor.col - 1
    end
  end

  utils.set_real_cursor(real_row, real_col)
end

-- ─── Autocmds ────────────────────────────────────────────────────────────────

local augroup = vim.api.nvim_create_augroup("MulticursorInput", { clear = true })

function M.attach()
  -- Flush any accumulated insert text when leaving insert mode
  vim.api.nvim_create_autocmd("InsertLeave", {
    group    = augroup,
    callback = function()
      if not state.active then return end
      if insert_buf ~= "" then
        replay_insert(insert_buf)
        insert_buf = ""
      end
      in_insert = false
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group    = augroup,
    callback = function()
      if not state.active then return end
      in_insert  = true
      insert_buf = ""
    end,
  })

  -- For normal-mode operations we hook into TextChanged (after the fact)
  -- and re-synchronise all extmarks. A more precise approach hooks
  -- on_key (below) for specific command keys.
end

-- ─── on_key handler ──────────────────────────────────────────────────────────
-- Intercepts every key in insert mode and buffers printable characters.
-- Special keys trigger immediate replay.

local key_handler_id = nil

function M.start_key_capture()
  if key_handler_id then return end
  key_handler_id = vim.on_key(function(key)
    if not state.active then return end
    if not in_insert   then return end

    local decoded = vim.fn.keytrans(key)

    if decoded == "<BS>" then
      -- Flush current buffer first, then backspace
      if insert_buf ~= "" then
        replay_insert(insert_buf)
        insert_buf = ""
      end
      replay_backspace()
      return
    end

    if decoded == "<CR>" then
      if insert_buf ~= "" then
        replay_insert(insert_buf)
        insert_buf = ""
      end
      -- newline via normal! on each cursor
      replay_normal("a\n\x1b")
      return
    end

    -- Ignore non-printable / special keys
    if decoded:sub(1, 1) == "<" then return end

    -- Accumulate printable chars; flush on next special or InsertLeave
    insert_buf = insert_buf .. key
  end, M.ns_id)
end

function M.stop_key_capture()
  if key_handler_id then
    -- on_key handlers cannot be removed individually in older nvim;
    -- we rely on the `state.active` guard instead.
    key_handler_id = nil
  end
end

-- Expose replay helpers for use by the main module
M.replay_normal   = replay_normal
M.replay_insert   = replay_insert
M.replay_backspace = replay_backspace

return M

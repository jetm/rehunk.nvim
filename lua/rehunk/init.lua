--- rehunk.nvim - Automatic diff header recalculation for git add -p
--- Neovim integration layer
local M = {}

local core = require('rehunk.core')

--- Default configuration (zero-config ready)
M.config = {
  auto_recalculate = true, -- Recalculate on BufWritePre
}

--- Setup function (optional - plugin works without calling this)
--- @param opts table|nil User configuration options
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

--- Format feedback message from changes array
--- @param changes table[] Array of {hunk=number, old=string, new=string}
--- @return string Formatted feedback message
local function format_feedback(changes)
  if #changes == 0 then
    return 'Rehunk: No hunks found'
  end

  local parts = {}
  local any_changed = false

  for _, change in ipairs(changes) do
    local changed = change.old ~= change.new
    if changed then
      any_changed = true
      table.insert(parts, string.format('Hunk %d: %s -> %s', change.hunk, change.old, change.new))
    else
      table.insert(parts, string.format('Hunk %d: unchanged', change.hunk))
    end
  end

  if not any_changed then
    return 'Rehunk: No changes needed'
  end

  return 'Rehunk: ' .. table.concat(parts, ' | ')
end

--- Recalculate hunk headers in a buffer
--- @param bufnr number|nil Buffer number (defaults to current)
--- @return boolean Success status
function M.recalculate(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get all buffer lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Call core recalculation
  local result, err = core.recalculate(lines)

  if not result then
    -- Error occurred - notify and return false
    vim.notify('Rehunk: ' .. err, vim.log.levels.ERROR)
    return false
  end

  -- Check if any headers actually changed
  local any_changed = false
  for _, change in ipairs(result.changes) do
    if change.old ~= change.new then
      any_changed = true
      break
    end
  end

  -- Update buffer if changes were made
  if any_changed then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)
  end

  -- Show feedback
  local feedback = format_feedback(result.changes)
  vim.notify(feedback, vim.log.levels.INFO)

  return true
end

--- Attach plugin functionality to a buffer
--- Creates buffer-local command and BufWritePre hook
--- @param bufnr number|nil Buffer number (defaults to current)
function M.attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Create buffer-local :RehunkRecalculate command
  vim.api.nvim_buf_create_user_command(bufnr, 'RehunkRecalculate', function()
    M.recalculate(bufnr)
  end, {
    desc = 'Recalculate hunk header line counts',
  })

  -- Create BufWritePre autocmd if auto_recalculate is enabled
  if M.config.auto_recalculate then
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = bufnr,
      callback = function()
        M.recalculate(bufnr)
      end,
      desc = 'Auto-recalculate hunk headers before save',
    })
  end
end

return M

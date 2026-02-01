--- rehunk.nvim plugin autoloader
--- Registers autocommands for automatic detection of git add -p edit buffers

-- Prevent double-loading
if vim.g.loaded_rehunk ~= 1 then
  return
end
vim.g.loaded_rehunk = 1

-- Create augroup for plugin autocommands
local augroup = vim.api.nvim_create_augroup('Rehunk', { clear = true })

-- Register autocommands to detect git add -p hunk edit buffers
-- Match both modern (C implementation) and legacy (Perl) patterns
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  group = augroup,
  pattern = { '*addp-hunk-edit.diff', '*ADDP_HUNK_EDIT.diff' },
  callback = function(args)
    require('rehunk').attach(args.buf)
  end,
  desc = 'Attach rehunk to git hunk edit buffers',
})

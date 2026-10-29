-- Helpers shared by the after/ftplugin files
local M = {}

-- Append `cmd` to b:undo_ftplugin, once, so that it runs when the buffer
-- changes filetype
function M.add_undo(cmd)
  local undo = vim.b.undo_ftplugin or ''
  if not undo:find(cmd, 1, true) then
    vim.b.undo_ftplugin = (undo ~= '' and undo .. ' | ' or '') .. cmd
  end
end

return M

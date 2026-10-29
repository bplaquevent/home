-- Indentation in LUA files
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.expandtab = true

-- Restored when the buffer changes filetype (:set ft=php), or the 2-space
-- indentation would stick to it
require('config.ftplugin').add_undo('setlocal shiftwidth< tabstop< expandtab<')

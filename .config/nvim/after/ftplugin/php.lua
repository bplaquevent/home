-- Red ruler at column 121 (ColorColumn colour set in config/autocmds.lua)
vim.opt_local.colorcolumn = '121'

-- Removed when the buffer changes filetype (:set ft=text)
require('config.ftplugin').add_undo('setlocal colorcolumn<')

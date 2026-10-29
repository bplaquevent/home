vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.opt.mouse = 'a'
vim.opt.visualbell = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.number = true
vim.opt.showmatch = true
vim.opt.title = true
vim.opt.showtabline = 2
vim.opt.foldmethod = 'marker'
-- termguicolors is left to Neovim's own detection (0.10+): forcing it would send
-- 24-bit colours to terminals that cannot show them (screen, tmux without RGB)

-- Swap files (on by default) allow recovery after a crash; they are turned off
-- for the decrypted copies of pass, mutt, sudoedit, ansible-vault, sops and
-- kubectl edit in config/autocmds.lua.
-- No persistent undo: it would keep every past state of every file on disk.

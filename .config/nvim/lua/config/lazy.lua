-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- import your plugins
    { import = "plugins" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})

-- Map <C-e> to open the diagnostic floating window
vim.keymap.set('n', '<C-e>', ':lua vim.diagnostic.open_float({ border="single" })<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-t>', ':tabnew<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-d>', ':tabclose<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-Left>', ':tabprevious<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-Right>', ':tabnext<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<A-Left>', ':Neotree toggle current show filesystem left reveal_force_cwd focus<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<A-Right>', ':Neotree toggle current show buffers right focus<CR>', { noremap = true, silent = true })

-- Indentation in PHP files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "php",
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.expandtab = true
    vim.opt.colorcolumn = '121'
    vim.opt.termguicolors = true
    vim.cmd('highlight ColorColumn guibg=NvimDarkRed')
  end,
})

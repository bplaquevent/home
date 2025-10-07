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

vim.opt.compatible = false
vim.opt.fileformat = 'unix'
vim.opt.encoding = 'utf-8'
vim.opt.mouse = 'a'
vim.opt.visualbell = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.number = true
vim.opt.wrap = true
vim.opt.showmatch = true
vim.opt.title = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.wrapscan = true
vim.opt.ignorecase = false
vim.opt.showtabline = 2
vim.opt.foldmethod = 'marker'
vim.opt.hlsearch = true
vim.opt.laststatus = 2
vim.opt.swapfile = false

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
    vim.lsp.enable('phpactor')
  end,
})

-- Indentation in LUA files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua",
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.expandtab = true
  end,
})

-- Fonction "Home" intelligente
local function smart_home()
  local line = vim.api.nvim_get_current_line()
  local first_nonblank = line:find('%S') or 1
  local col = vim.fn.col('.')

  if col ~= first_nonblank then
    -- Aller au premier caractère non blanc
    vim.fn.cursor(vim.fn.line('.'), first_nonblank)
  else
    -- Aller tout au début de la ligne (colonne 1)
    vim.fn.cursor(vim.fn.line('.'), 1)
  end
end

-- Mode Insert : déplacement direct sans utiliser <C-O> (évite les bugs avec nvim-cmp)
vim.keymap.set('i', '<Home>', function()
  smart_home()
end, { silent = true })

-- Mode Normal et Visuel : comportement identique
vim.keymap.set({ 'n', 'v' }, '<Home>', smart_home, { silent = true })

local function trim_trailing_whitespace()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Vérifie si le buffer est modifiable
  if not vim.api.nvim_buf_get_option(bufnr, 'modifiable') then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local modified = false

  for i, line in ipairs(lines) do
    local trimmed = line:gsub('%s+$', '')
    if trimmed ~= line then
      lines[i] = trimmed
      modified = true
    end
  end

  if modified then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePre' }, {
  pattern = '*',
  callback = trim_trailing_whitespace,
})


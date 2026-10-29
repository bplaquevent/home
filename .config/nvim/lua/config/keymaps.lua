-- Diagnostics and tabs live under <leader> so that the native <C-e> (scroll),
-- <C-d> (half-page down) and <C-t> (tag stack) keep working
vim.keymap.set('n', '<leader>e', function() vim.diagnostic.open_float({ border = "single" }) end,
  { desc = "Diagnostic flottant" })
vim.keymap.set('n', '<leader>tn', '<Cmd>tabnew<CR>', { desc = "Nouvel onglet" })
vim.keymap.set('n', '<leader>td', function()
  -- :tabclose fails with E784 on the last tab page
  if #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd.tabclose()
  else
    vim.notify("Dernier onglet : rien à fermer", vim.log.levels.INFO)
  end
end, { desc = "Fermer l'onglet" })
vim.keymap.set('n', '<C-Left>', '<Cmd>tabprevious<CR>')
vim.keymap.set('n', '<C-Right>', '<Cmd>tabnext<CR>')
vim.keymap.set('n', '<A-Left>', '<Cmd>Neotree toggle focus filesystem left reveal_force_cwd<CR>')
vim.keymap.set('n', '<A-Right>', '<Cmd>Neotree toggle focus buffers right<CR>')

-- Fonction "Home" intelligente
local function smart_home()
  local line = vim.api.nvim_get_current_line()
  local first_nonblank = line:find('%S') or 1
  local col = vim.fn.col('.')

  -- Après un opérateur (d<Home>, c<Home>), jamais vers l'avant : depuis
  -- l'indentation, d<Home> agit comme d0 (vers la colonne 1) et non comme d^
  -- (vers l'avant, jusqu'au premier caractère non blanc)
  local pending = vim.api.nvim_get_mode().mode:sub(1, 2) == 'no'
  if col ~= first_nonblank and not (pending and col < first_nonblank) then
    -- Aller au premier caractère non blanc
    vim.fn.cursor(vim.fn.line('.'), first_nonblank)
  else
    -- Aller tout au début de la ligne (colonne 1)
    vim.fn.cursor(vim.fn.line('.'), 1)
  end
end

-- Déplacement direct sans utiliser <C-O> en mode Insert (évite les bugs avec nvim-cmp).
-- Aussi en mode opérateur, pour que d<Home> ou y<Home> suivent le même mouvement.
vim.keymap.set({ 'n', 'v', 'o', 'i' }, '<Home>', smart_home, { silent = true })

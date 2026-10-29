return {
  {
    'hrsh7th/nvim-cmp',
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-cmdline',
      'hrsh7th/cmp-vsnip',
      'hrsh7th/vim-vsnip',
    },
    config = function()
      local cmp = require('cmp')

      -- cmp-buffer indexes the whole buffer and refreshes on every keystroke
      -- (keyword_length = 0): skip multi-MB logs and dumps, which would lag
      local function small_buffers()
        local buf = vim.api.nvim_get_current_buf()
        local size = vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf))
        return size <= 1024 * 1024 and { buf } or {}
      end

      local function feed(keys)
        vim.api.nvim_feedkeys(vim.keycode(keys), '', true)
      end

      -- <Tab> confirms only right after part of a name (word character, accented
      -- letter, a member-access `.`, or the PHP `$`, `->`, `::` and `\`), so it
      -- still inserts a tab after a space, a `;`, a `=>`, a number or a ternary
      -- `:` while the menu is open, unless an item was picked by hand.
      -- Otherwise it jumps to the next snippet placeholder, if any.
      local function confirm_or_tab(fallback)
        local before = vim.api.nvim_get_current_line():sub(1, vim.fn.col('.') - 1)
        -- A number (`=> 1`, `1.`) is not a name: <Tab> there aligns a comment
        local after_name = not before:match('%f[%w_]%d+%.?$')
          and (before:match('[%w_$\\\128-\255]$') or before:match('%->$') or before:match('::$')
            -- member access in other languages (vim.api., obj.)
            or before:match('[%w_)%]]%.$'))
        -- An item picked by hand with <Up>/<Down> is always accepted
        if cmp.visible() and (after_name or cmp.get_selected_entry())
            and cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }) then
          return
        elseif vim.fn['vsnip#jumpable'](1) == 1 then
          feed('<Plug>(vsnip-jump-next)')
        else
          fallback()
        end
      end

      local function snippet_prev(fallback)
        if vim.fn['vsnip#jumpable'](-1) == 1 then
          feed('<Plug>(vsnip-jump-prev)')
        else
          fallback()
        end
      end

      cmp.setup({
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = {
          ['<C-Space>'] = cmp.mapping.complete(),
          -- <CR> only confirms an item picked with <Up>/<Down>, otherwise it is a
          -- plain newline; <Tab> is the shortcut that accepts the first item
          ['<CR>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = false,
          }),
          ['<Tab>'] = cmp.mapping(confirm_or_tab, { 'i' }),
          ['<S-Tab>'] = cmp.mapping(snippet_prev, { 'i' }),
          ['<Up>'] = cmp.mapping.select_prev_item(),
          ['<Down>'] = cmp.mapping.select_next_item(),
        },
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'vsnip' },
        }, {
          -- Second group: shown only when the LSP has nothing, or every `/` in
          -- code (`// comment`, `$a / $b`) would list the filesystem
          { name = 'path' },
          { name = 'buffer', option = { get_bufnrs = small_buffers } },
        }),
        -- Otherwise an item the server flags as preselected is selected despite
        -- 'noselect', and <CR> confirms it instead of inserting a newline
        preselect = cmp.PreselectMode.None,
        completion = {
          keyword_length = 0,
          completeopt = 'menu,menuone,noselect',
        },
        experimental = {
          ghost_text = true,
        },
      })

      -- nvim-cmp only installs its mappings in Insert and Cmdline modes, but vsnip
      -- leaves each placeholder selected (Select mode): map the jumps there too
      vim.keymap.set('s', '<Tab>', function()
        return vim.fn['vsnip#jumpable'](1) == 1 and '<Plug>(vsnip-jump-next)' or '<Tab>'
      end, { expr = true, remap = true })
      vim.keymap.set('s', '<S-Tab>', function()
        return vim.fn['vsnip#jumpable'](-1) == 1 and '<Plug>(vsnip-jump-prev)' or '<S-Tab>'
      end, { expr = true, remap = true })

      -- keyword_length=0 above would open the menu on every keystroke after
      -- ':' and '/': on the command line, wait for a couple of characters
      cmp.setup.cmdline({ '/', '?' }, {
        completion = { keyword_length = 2 },
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = 'buffer', option = { get_bufnrs = small_buffers } } },
      })

      cmp.setup.cmdline(':', {
        completion = { keyword_length = 2 },
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = 'path' } }, { { name = 'cmdline' } }),
      })
    end,
  },
}

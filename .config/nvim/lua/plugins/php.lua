return {
  {
    'hrsh7th/nvim-cmp',
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      'neovim/nvim-lspconfig',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-cmdline',
      'hrsh7th/cmp-vsnip',
      'hrsh7th/vim-vsnip',
    },
    config = function()
      local cmp = require('cmp')
      local cmp_nvim_lsp = require('cmp_nvim_lsp')
      local phpactor_config = vim.lsp.config(
        'phpactor',
        {
          capabilities = cmp_nvim_lsp.default_capabilities(),
          cmd = { 'phpactor', 'language-server', '-vvv' },
          init_options = {
            ['language_server_phpstan.enabled'] = true,
            ['language_server_php_cs_fixer.enabled'] = true,
            ['symfony.enabled'] = true,
            ['composer.enable'] = true,
            ['composer.autoloader_path'] = '%project_root%/vendor/autoload.php',
            ['composer.class_maps_only'] = true,
            ['completion_worse.completor.doctrine_annotation.enabled'] = true,
            ['completion_worse.completor.imported_names.enabled'] = true,
            ['completion_worse.completor.worse_parameter.enabled'] = true,
            ['completion_worse.completor.named_parameter.enabled'] = true,
            ['completion_worse.completor.constructor.enabled'] = true,
            ['completion_worse.completor.class_member.enabled'] = true,
            ['completion_worse.completor.scf_class.enabled'] = false,
            ['completion_worse.completor.local_variable.enabled'] = true,
            ['completion_worse.completor.subscript.enabled'] = false,
            ['completion_worse.completor.declared_function.enabled'] = true,
            ['completion_worse.completor.declared_constant.enabled'] = true,
            ['completion_worse.completor.declared_class.enabled'] = true,
            ['completion_worse.completor.expression_name_search.enabled'] = true,
            ['completion_worse.completor.use.enabled'] = true,
            ['completion_worse.completor.attribute.enabled'] = true,
            ['completion_worse.completor.class_like.enabled'] = true,
            ['completion_worse.completor.type.enabled'] = true,
            ['completion_worse.completor.keyword.enabled'] = true,
            ['completion_worse.completor.docblock.enabled'] = true,
            ['completion_worse.completor.constant.enabled'] = true,
            ['completion_worse.completor.class.limit'] = 100,
            ['completion_worse.name_completion_priority'] = 'proximity',
            ['completion_worse.snippets'] = true,
            ['completion_worse.experimantal'] = false,
            ['completion_worse.debug'] = false,
            ['completion.dedupe'] = true,
            ['completion.dedupe_match_fqn'] = true,
            ['completion.limit'] = 100,
            ['completion.label_formatter'] = 'fqn',
          },
        }
      )
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
          ['<CR>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          }),
          ['<Tab>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          }),
          ['<Up>'] = cmp.mapping.select_prev_item(),
          ['<Down>'] = cmp.mapping.select_next_item(),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'vsnip' },
        },
        completion = {
          keyword_length = 0,
--          autocomplete = false,
          completeopt = 'menu,menuone,noinsert,preview,longest',
        },
        experimental = {
          ghost_text = true,
        },
      })
      vim.lsp.set_log_level("debug")
    end,
  },
}


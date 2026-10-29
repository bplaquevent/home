-- PHP is not installed on the host: phpactor (a PHAR) runs in this image
local php_image = 'php:8.3-cli-alpine'

-- Bind mount at the same path inside the container. --mount (unlike -v) does not
-- split on ':', and quoting each field protects paths that contain a ','
local function bind(path, readonly, target)
  local spec = string.format('type=bind,"src=%s","dst=%s"', path, target or path)
  return { '--mount', readonly and spec .. ',readonly' or spec }
end

-- Only a self-contained PHAR can be mounted alone into the container: a
-- composer global install or a wrapper script resolves paths that do not exist
-- there. A PHAR stub ends with __HALT_COMPILER within its first bytes. Read
-- every time (root_dir runs for each PHP buffer opened), so that installing or
-- replacing phpactor later in the session is picked up.
local function is_phar(path)
  local file = path ~= '' and io.open(path, 'rb')
  if not file then
    return false
  end
  local head = file:read(8192) or ''
  file:close()
  return head:find('__HALT_COMPILER', 1, true) ~= nil
end

-- Without access to the daemon, every PHP buffer would start a `docker run`
-- that fails at once. Checking the sockets is instant, unlike a blocking
-- `docker info`. DOCKER_HOST, DOCKER_CONTEXT or a context selected with
-- `docker context use` (remote, rootless...) are trusted as is.
local function docker_reachable()
  if vim.env.DOCKER_HOST or vim.env.DOCKER_CONTEXT then
    return true
  end
  local config = (vim.env.DOCKER_CONFIG or vim.fn.expand('~/.docker')) .. '/config.json'
  local context = vim.fn.filereadable(config) == 1
    and vim.fn.join(vim.fn.readfile(config), '\n'):match('"currentContext"%s*:%s*"([^"]*)"')
  -- "default" is the system socket, checked below
  if context and context ~= '' and context ~= 'default' then
    return true
  end
  -- Without them, the CLI only talks to the system socket (a rootless socket in
  -- $XDG_RUNTIME_DIR is used through DOCKER_HOST or a context, handled above)
  return vim.uv.fs_access('/var/run/docker.sock', 'RW') == true
end

-- PHAR that passed the availability check in root_dir, per project root: the
-- one phpactor_cmd mounts for that root (PATH may differ between projects)
local phpactor_phars = {}

-- Composer path repositories are symlinked into vendor/ from outside the
-- project, and vendor/ itself may be a symlink: their targets must be mounted
-- too, or phpactor cannot read them. Returns { src, dst } pairs: dst is where
-- the container looks (a relative link is followed from its own directory as
-- seen in the container), src the resolved host path. `seen` holds the mount
-- points already used: Docker refuses to start on one given twice.
local function external_mounts(root, seen)
  local mounts = {}
  local real_root = vim.uv.fs_realpath(root) or root
  local function outside(path, dir)
    return path ~= dir and not vim.startswith(path, dir .. '/')
  end
  -- Mounts the target of the link `host` (seen as `container` in the container)
  -- if it leads out of the project; returns where the container finds it
  local function follow(container, host)
    local src = vim.uv.fs_realpath(host)
    local text = vim.uv.fs_readlink(host)
    if not (src and text) then
      return nil
    end
    local dst = vim.fs.normalize(vim.startswith(text, '/') and text
      or vim.fs.joinpath(vim.fs.dirname(container), text))
    if not outside(dst, root) and outside(src, real_root) then
      -- Inside the root, but through a symlinked directory leading out of it:
      -- the container follows that one to its own target
      dst = src
    end
    if outside(dst, root) and not seen[dst] then
      seen[dst] = true
      table.insert(mounts, { src, dst })
    end
    return dst
  end

  local vendor_container, vendor_host = root .. '/vendor', root .. '/vendor'
  local stat = vim.uv.fs_lstat(vendor_host)
  if stat and stat.type == 'link' then
    vendor_container = follow(vendor_container, vendor_host)
    vendor_host = vim.uv.fs_realpath(vendor_host)
  end
  if not (vendor_container and vendor_host) or vim.fn.isdirectory(vendor_host) == 0 then
    return mounts
  end
  for name, type in vim.fs.dir(vendor_host, { depth = 2 }) do
    if type == 'link' then
      follow(vendor_container .. '/' .. name, vendor_host .. '/' .. name)
    end
  end
  return mounts
end

-- Start phpactor in a throwaway container. The project root and the phpactor
-- cache are mounted at their host paths so that file URIs match on both sides.
local function phpactor_cmd(dispatchers, config)
  local root = config.root_dir
  local home = vim.env.HOME
  local cache = home .. '/.cache/phpactor'
  local global_config = home .. '/.config/phpactor'
  vim.fn.mkdir(cache, 'p')
  -- The image ships no php.ini, so memory_limit is 128M: too little to index a
  -- large project or run phpstan. PHP_INI_SCAN_DIR (inherited by the phpstan and
  -- php-cs-fixer processes) adds this file to the image's own conf.d. Capped
  -- rather than unlimited, so that a runaway analysis cannot eat all host RAM.
  local ini_dir = cache .. '/php-ini'
  local ini_file = ini_dir .. '/memory.ini'
  local ini = { 'memory_limit = 2G' }
  if vim.fn.filereadable(ini_file) == 0 or not vim.deep_equal(vim.fn.readfile(ini_file), ini) then
    vim.fn.mkdir(ini_dir, 'p')
    vim.fn.writefile(ini, ini_file)
  end
  local cmd = {
    'docker', 'run', '--rm', '-i', '--init',
    '--user', vim.uv.getuid() .. ':' .. vim.uv.getgid(),
    '-e', 'HOME=' .. home,
    '-e', 'PHP_INI_SCAN_DIR=:' .. ini_dir,
    '-w', root,
    -- Without it, Docker creates $HOME as root when mounting the cache below,
    -- and phpactor cannot write its other XDG directories (data, state)
    '--mount', string.format('type=tmpfs,"dst=%s",tmpfs-mode=1777', home),
  }
  -- Fallback for a restart (:lsp restart) after this module was reloaded, which
  -- runs cmd again without root_dir
  local phar = phpactor_phars[root] or vim.fn.exepath('phpactor')
  if not is_phar(phar) then
    error('phpactor introuvable dans le PATH, ou pas un PHAR autonome')
  end
  vim.list_extend(cmd, bind(phar, true, '/opt/phpactor'))
  vim.list_extend(cmd, bind(cache))
  vim.list_extend(cmd, bind(root))
  local seen = { [home] = true, [root] = true, [cache] = true, [global_config] = true, ['/opt/phpactor'] = true }
  for _, target in ipairs(external_mounts(root, seen)) do
    vim.list_extend(cmd, bind(target[1], true, target[2]))
  end
  -- Global phpactor.json, otherwise invisible from inside the container
  if vim.fn.isdirectory(global_config) == 1 then
    vim.list_extend(cmd, bind(global_config, true))
  end
  vim.list_extend(cmd, { php_image, 'php', '/opt/phpactor', 'language-server' })
  return vim.lsp.rpc.start(cmd, dispatchers, { cwd = root })
end

return {
  {
    -- Not lazy-loaded: the server configs it ships (lsp/*.lua) must be on the
    -- runtimepath before the first FileType event, or vim.lsp.enable() finds nothing
    'neovim/nvim-lspconfig',
    dependencies = { 'hrsh7th/cmp-nvim-lsp' },
    config = function()
      vim.lsp.config('*', {
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
      })

      vim.lsp.config('phpactor', {
        cmd = phpactor_cmd,
        -- $HOME is itself a git repository (dotfiles): a PHP file outside any
        -- project would otherwise get $HOME as root, mounted and indexed whole
        root_dir = function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, { { 'composer.json', '.phpactor.json', '.phpactor.yml' }, '.git' })
          -- A package file opened from vendor/ (go to definition) belongs to the
          -- project around it, not to the package's own composer.json: one
          -- phpactor per project, which sees the project's autoloader. Only for
          -- vendor/<org>/<pkg> under a Composer project, not for a project that
          -- merely lives in a directory named vendor.
          local project = root and root:match('^(.*)/vendor/[^/]+/[^/]+$')
          if project and vim.uv.fs_stat(project .. '/composer.json') then
            root = project
          end
          -- Resolved on both sides: a symlinked $HOME (or one with a trailing /)
          -- must not slip through the comparison
          local real = vim.uv.fs_realpath
          if not root or real(root) == real(vim.env.HOME) then
            return
          end
          -- A server already runs for this project: nothing left to check
          for _, client in ipairs(vim.lsp.get_clients({ name = 'phpactor' })) do
            if client.root_dir == root then
              on_dir(root)
              return
            end
          end
          -- Checked when a project's first PHP buffer opens rather than once at
          -- startup: no cost for sessions without PHP, and a later install is
          -- picked up
          local phpactor = vim.fn.exepath('phpactor')
          local missing = vim.fn.executable('docker') == 0 and 'docker introuvable'
            or not docker_reachable() and 'démon docker inaccessible (arrêté, ou utilisateur hors du groupe docker)'
            or phpactor == '' and 'phpactor introuvable'
            or not is_phar(phpactor) and 'phpactor doit être un PHAR autonome'
          if missing then
            vim.notify_once('phpactor désactivé : ' .. missing, vim.log.levels.WARN)
            return
          end
          phpactor_phars[root] = phpactor
          on_dir(root)
        end,
        -- phpstan and php-cs-fixer are not in the container image: only enable
        -- them when the project ships them in vendor/bin, or phpactor reports
        -- an error on every diagnostic and formatting run
        before_init = function(params, config)
          -- Copy: the table is shared with the config, reused for other projects
          local opts = vim.deepcopy(params.initializationOptions)
          params.initializationOptions = opts
          for key, tool in pairs({
            ['language_server_phpstan.enabled'] = 'phpstan',
            ['language_server_php_cs_fixer.enabled'] = 'php-cs-fixer',
          }) do
            opts[key] = opts[key] and vim.fn.executable(config.root_dir .. '/vendor/bin/' .. tool) == 1
          end
        end,
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
          -- Misspelled on purpose: this is phpactor's actual key (CompletionWorseExtension)
          ['completion_worse.experimantal'] = false,
          ['completion_worse.debug'] = false,
          ['completion.dedupe'] = true,
          ['completion.dedupe_match_fqn'] = true,
          ['completion.limit'] = 100,
          ['completion.label_formatter'] = 'fqn',
        },
      })

      vim.lsp.enable('phpactor')
    end,
  },
}

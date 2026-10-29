-- One group, cleared on each load, so that re-sourcing does not stack duplicates
local group = vim.api.nvim_create_augroup('user_autocmds', { clear = true })

-- Whether one of the parts of the buffer's filetype is a key of `set`: compound
-- filetypes ("php.html", "markdown.pandoc") run each part's ftplugin
local function has_ft(buf, set)
  for _, ft in ipairs(vim.split(vim.bo[buf].filetype, '.', { plain = true })) do
    if set[ft] then
      return true
    end
  end
  return false
end

-- Whether an autocmd's <afile> is the buffer's own file. Both sides are resolved
-- (symlinks, `..`, relative paths after :lcd), or a mere spelling difference
-- would silently be taken for a write to another file.
local function is_own_file(args)
  local name = vim.api.nvim_buf_get_name(args.buf)
  return name ~= '' and vim.fn.resolve(vim.fn.fnamemodify(args.file, ':p')) == vim.fn.resolve(name)
end

-- Red ColorColumn, for the ruler that after/ftplugin/php.lua puts at column
-- 121. Reapplied after each colorscheme change, which would otherwise reset it,
-- and after each 'background' change: without a colorscheme, switching it
-- (late terminal OSC 11 reply, terminal theme switch, :set bg=light) reloads
-- the default groups without firing ColorScheme. OptionSet is not triggered
-- during startup, hence VimEnter for a reply that arrives before it.
local function set_colorcolumn_hl()
  vim.api.nvim_set_hl(0, 'ColorColumn', { bg = 'NvimDarkRed', ctermbg = 'DarkRed' })
end
set_colorcolumn_hl()
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, { group = group, callback = set_colorcolumn_hl })
vim.api.nvim_create_autocmd("OptionSet", { group = group, pattern = 'background', callback = set_colorcolumn_hl })

-- Directories where pass (/dev/shm), mutt (~/.mutt/tmp), sudoedit (/var/tmp) and
-- ansible-vault (~/.ansible/tmp) put the decrypted copy of a secret for a
-- short-lived editor
local secret_dirs = vim.tbl_map(function(dir)
  -- Resolved like the paths compared to them: ~/.mutt may be a dotfiles symlink
  return vim.fn.resolve(dir) .. '/'
end, { '/dev/shm', '/var/tmp', vim.fn.expand('~/.mutt/tmp'), vim.fn.expand('~/.ansible/tmp') })

-- Symlinks are resolved, or ~/scratch -> /dev/shm/x would slip through
local function in_secret_dir(path)
  path = vim.fn.resolve(path)
  for _, dir in ipairs(secret_dirs) do
    if vim.startswith(path, dir) then
      return true
    end
  end
  return false
end

-- kubectl edit drops its decrypted copy right in /tmp (or $TMPDIR), sops in a
-- numeric subdirectory of it (Go's os.MkdirTemp("", "")). Only those, not other
-- subdirectories (crontab -e, a project cloned in /tmp), and only their swap: a
-- build log opened from /tmp must not drop the session's ShaDa.
local function is_temp_copy(path)
  local dir = vim.fs.dirname(vim.fn.resolve(path))
  local parent = vim.fs.basename(dir):match('^%d+$') and vim.fs.dirname(dir)
  for _, tmp in ipairs({ '/tmp', vim.env.TMPDIR }) do
    if tmp and tmp ~= '' then
      tmp = vim.fn.resolve(vim.fs.normalize(tmp))
      if dir == tmp or parent == tmp then
        return true
      end
    end
  end
  return false
end

-- Trailing spaces are meaningful in these filetypes (Markdown hard line breaks, patches,
-- the "-- " mail signature delimiter and format=flowed in mutt drafts, the
-- patches of git send-email --annotate)
local keep_trailing_whitespace = { markdown = true, diff = true, gitcommit = true, mail = true, gitsendemail = true }

-- Bytes of space and tab. Not form feed: a line holding only ^L is a page break
-- (GNU C, Emacs Lisp, Python stdlib), which trimming would delete.
local blanks = { [32] = true, [9] = true }

-- Trim trailing whitespace of the whole file when a modified buffer is saved:
-- a plain :w of an untouched file leaves it as it is on disk.
-- Only the trailing blanks are replaced, so the cursor and marks stay in place.
vim.api.nvim_create_autocmd('BufWritePre', {
  group = group,
  callback = function(args)
    local bo = vim.bo[args.buf]
    -- Only when the buffer's own file is written: `:w /tmp/copy` must leave the
    -- buffer alone (partial writes fire FileWritePre/FileAppendPre, not this).
    -- A special buffer (acwrite) has no file of its own. In a secret copy (pass
    -- entry, sudoedit, sops, kubectl edit) a trailing space may be part of a password.
    local name = vim.api.nvim_buf_get_name(args.buf)
    if not is_own_file(args) or not bo.modified
        or bo.buftype ~= '' or not bo.modifiable or bo.binary
        or in_secret_dir(name) or is_temp_copy(name)
        or has_ft(args.buf, keep_trailing_whitespace) then
      return
    end
    for row, line in ipairs(vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)) do
      -- Spaces and tabs only, before any stray CR: in a mixed-endings file read
      -- as unix, that CR is the line ending, not trailing whitespace. Scanned
      -- backwards: a pattern like '[ \t]+$' backtracks quadratically on a long
      -- run of inner blanks (seconds for a 20k-space line in a data file).
      local last = line:byte(-1) == 13 and #line - 1 or #line
      local first = last
      while first > 0 and blanks[line:byte(first)] do
        first = first - 1
      end
      if first < last then
        vim.api.nvim_buf_set_text(args.buf, row - 1, first, row - 1, last, {})
      end
    end
  end,
})

-- The decrypted copy of a secret must not reach the disk through a swap file,
-- nor its yanked lines through ShaDa. 'shada' is global, so it is only cleared
-- when nvim was started on that file, which is how pass, mutt and sudoedit
-- spawn their editor: opening such a file from an everyday session must not
-- silently drop its history, registers and marks.
-- BufWritePre covers a buffer first written there (:saveas, a first :w of an
-- unnamed buffer), which never triggers BufNewFile or BufReadPre; `:w copy`
-- only writes a copy, and the buffer keeps its own swap.
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufReadPre', 'BufWritePre' }, {
  group = group,
  callback = function(args)
    local path = vim.fn.fnamemodify(args.file, ':p')
    local secret = in_secret_dir(path)
    if not (secret or is_temp_copy(path))
        or args.event == 'BufWritePre' and not is_own_file(args) then
      return
    end
    vim.bo[args.buf].swapfile = false
    if secret and args.event ~= 'BufWritePre' and vim.v.vim_did_enter == 0 then
      vim.opt.shada = ''
    end
  end,
})

-- `:r` of a secret copies it into the current buffer: no swap for that one either
vim.api.nvim_create_autocmd('FileReadPre', {
  group = group,
  callback = function(args)
    local path = vim.fn.fnamemodify(args.file, ':p')
    if in_secret_dir(path) or is_temp_copy(path) then
      vim.bo[args.buf].swapfile = false
    end
  end,
})

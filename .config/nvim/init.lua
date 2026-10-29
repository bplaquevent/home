-- Options first: mapleader must be set before lazy.nvim loads the plugins.
-- Autocmds and keymaps before lazy too: they must be in place even if a plugin
-- spec fails (the autocmds keep the swap files of secret copies off disk).
require("config.options")
require("config.autocmds")
require("config.keymaps")
require("config.lazy")

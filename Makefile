.PHONY: test setup

setup:
	[ -d test/plenary.nvim ] || git clone https://github.com/nvim-lua/plenary.nvim test/plenary.nvim

test: setup
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory test/automated/ { minimal_init = './scripts/minimal_init.vim' }"

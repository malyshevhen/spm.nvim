.PHONY: test

test:
	git submodule update --init --recursive
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory test/automated/ { minimal_init = './scripts/minimal_init.vim' }"


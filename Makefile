.PHONY: test test-toml test-encoder

test:
	git submodule update --init --recursive
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory test/automated/ { minimal_init = './scripts/minimal_init.vim' }"

test-toml:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory test/toml/spec/ { minimal_init = './scripts/minimal_init.vim' }"

test-encoder:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory test/toml/encoder/ { minimal_init = './scripts/minimal_init.vim' }"


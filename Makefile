.PHONY: setup test unit-test automated-test clean

# variables
PLUGIN_NAME=spm.nvim

XDG_CONFIG_HOME='test/xdg/config/'
XDG_STATE_HOME='test/xdg/local/state/'
XDG_DATA_HOME='test/xdg/local/share/'

PLUGIN_DIR=$(XDG_DATA_HOME)nvim/site/pack/testing/start

BUSTED="./test/bin/busted"

setup: # Create a simlink of the tested plugin in the fake XDG config directory
	@mkdir -p $(PLUGIN_DIR)
	@ln -s $(PWD) $(PLUGIN_DIR)/$(PLUGIN_NAME)

test: # Run all tests
	@($(MAKE) setup)
	@(trap 'make clean' EXIT; $(BUSTED) --run all)

unit-test:
	@($(MAKE) setup)
	@(trap 'make clean' EXIT; $(BUSTED) --run unit)

automated-test:
	@($(MAKE) setup)
	@(trap 'make clean' EXIT; $(BUSTED) --run automated)

clean:
	@rm -rf $(PLUGIN_DIR)


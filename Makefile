.PHONY: setup unit-test automated-test clean

# variables
XDG_CONFIG_HOME='test/xdg/config/'
XDG_STATE_HOME='test/xdg/local/state/'
XDG_DATA_HOME='test/xdg/local/share/'

PLUGIN_DIR=$(XDG_DATA_HOME)/nvim/site/pack/testing/start/spm.nvim

BUSTED="./test/bin/busted"

all:
	@echo "Run 'make unit-test' and 'make automated-test'"
	@($(MAKE) unit-test)
	@($(MAKE) automated-test)

setup: # Create a simlink of the tested plugin in the fake XDG config directory
	@ln -s $(PWD) $(PLUGIN_DIR)

unit-test:
	@($(MAKE) setup)
	@(trap 'make clean' EXIT; $(BUSTED) --run unit)

automated-test:
	@($(MAKE) setup)
	@(trap 'make clean' EXIT; $(BUSTED) --run automated)

clean:
	@rm -rf $(PLUGIN_DIR)


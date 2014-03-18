##############################
#  The MIT License (MIT)     #
#                            #
#  Copyright (c) 2014 gsick  #
##############################

##### Build defaults #####
LUA_VERSION       =    5.1
TARGET            =    openam.lua
PREFIX           ?=    /usr/local
INSTALL          ?=    install
LUA_INCLUDE_DIR   =    $(PREFIX)/include
LUA_CMODULE_DIR   =    $(PREFIX)/lib64/lua/$(LUA_VERSION)
LUA_MODULE_DIR    =    $(PREFIX)/share/lua/$(LUA_VERSION)
LUA_BIN_DIR       =    $(PREFIX)/bin

EXECPERM          =    755

all: ;

doc: README.md

install:
	$(INSTALL) -d $(DESTDIR)/$(LUA_MODULE_DIR)/openam
	$(INSTALL) lib/openam/$(TARGET) $(DESTDIR)/$(LUA_MODULE_DIR)/openam
#	chmod $(EXECPERM) $(DESTDIR)/$(LUA_MODULE_DIR)/openam/$(TARGET)

clean:
	rm -rf $(DESTDIR)/$(LUA_MODULE_DIR)/openam

# Makefile for building and installing creolehtml
# Assumes a working euphoria installation

CONFIG_FILE = config.gnu

ifndef CONFIG
CONFIG = $(CONFIG_FILE)
endif

include $(CONFIG_FILE)

CREOLE= \
	$(wildcard *.e)

ifeq "$(PREFIX)" ""
PREFIX=/usr/local
endif

all : build/creolehtml

build/main-.c build/creole.mak : creole.ex $(CREOLE)
	-mkdir build
	cd build && euc -makefile ../creole.ex

build/creole : build/main-.c build/creole.mak
	 $(MAKE) -C build -f creole.mak

install : build/creole
	install build/creole $(DESTDIR)$(PREFIX)/bin
	-mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/creole
	install -p *.e $(DESTDIR)$(PREFIX)/share/euphoria/creole

uninstall :
	-rm $(DESTDIR)$(PREFIX)/bin/creole
	-rm -rf $(DESTDIR)$(PREFIX)/share/euphoria/creole

clean :
	-rm -rf build

distclean : clean
	rm Makefile $(CONFIG_FILE)

.PHONY : all clean install uninstall disclean

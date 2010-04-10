# Makefile for building and installing creolehtml
# Assumes a working euphoria installation

CREOLE= \
	$(wildcard *.e)

ifeq "$(PREFIX)" ""
PREFIX=/usr/local
endif


all : build/creolehtml

build/main-.c build/creolehtml.mak : creolehtml.ex $(CREOLE)
	-mkdir build
	cd build && euc -makefile-full ../creolehtml.ex

build/creolehtml : build/main-.c build/creolehtml.mak
	 $(MAKE) -C build -f creolehtml.mak

install : build/creolehtml
	install build/creolehtml $(DESTDIR)$(PREFIX)/bin
	-mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/creole
	install -p *.e $(DESTDIR)$(PREFIX)/share/euphoria/creole

uninstall :
	-rm $(DESTDIR)$(PREFIX)/bin/creolehtml
	-rm -rf $(DESTDIR)$(PREFIX)/share/euphoria/creolehtml

clean :
	-rm -rf build

distclean : clean
	rm Makefile
.PHONY : all clean install uninstall disclean

# Makefile for building and installing creolehtml
# Assumes a working euphoria installation

CONFIG_FILE = config.gnu

ifndef CONFIG
CONFIG = $(CONFIG_FILE)
endif

include $(CONFIG_FILE)

INCLUDE_SOURCE= \
	$(wildcard *.e)

ifeq "$(PREFIX)" ""
PREFIX=/usr/local
endif

all : build/creole

# A rule like this example below only makes the targets that go inside of it 
# always run.   When build/main-.c is created the timestamp of build is updated.
# So, build cannot be a prerequisite of anything inside build. :(
# 
#	build :
#		mkdir build

build/main-.c : creole.ex $(INCLUDE_SOURCE)
	-mkdir build
	cd build && euc -gcc -con -makefile ../creole.ex

build/creole.mak : build/main-.c

build/creole : build/main-.c build/creole.mak
	 $(MAKE) -C build -f creole.mak

install : build/creole
	install build/creole $(DESTDIR)$(PREFIX)/bin
	-mkdir -p $(DESTDIR)$(PREFIX)/share/euphoria/creole
	install -p *.e $(DESTDIR)$(PREFIX)/share/euphoria/creole

uninstall :
	-rm $(DESTDIR)$(PREFIX)/bin/creole
	-rm -rf $(DESTDIR)$(PREFIX)/share/euphoria/creole

# remove intermediate files without marking things as out of date.
# make will report "nothing to be done" unless sources are changed.
mostlyclean :
	-rm -f build/*.{o,obj,c,mak} build/main-.h build/creole.lnk
	
clean :
	-rm -rf build

distclean : clean
	rm Makefile $(CONFIG_FILE)

.PHONY : all clean install uninstall disclean mostlyclean
# Allows you to remove the intermediate C files without unecessarily 
# remaking them the next time you run make.
.SECONDARY : build/main-.c build/creole.mak

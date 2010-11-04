# Makefile for building and installing eudoc
# Assumes a working euphoria installation

!include config.wat

CREOLEHTML= creole.e filreadr.e html_gen.e kanarie.e seqreadr.e txtreadr.e

!ifndef PREFIX
PREFIX=$(%EUDIR)
!endif

all : .SYMBOLIC build\creolehtml.exe

build\main-.c build\creolehtml.mak : creolehtml.ex $(CREOLEHTML)
	-mkdir build
	cd build
	euc -makefile -con ..\creolehtml.ex
	cd ..

build\creolehtml.exe : build\main-.c build\creolehtml.mak
	 cd build
	$(MAKE) -f creolehtml.mak
	cd ..

install : .SYMBOLIC
	copy build\creolehtml.exe $(PREFIX)\bin\

uninstall : .SYMBOLIC 
	-del $(PREFIX)\bin\creolehtml.exe

clean : .SYMBOLIC 
	-del /S /Q build

distclean : .SYMBOLIC clean
	-del Makefile

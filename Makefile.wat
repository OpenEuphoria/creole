# Makefile for building and installing eudoc
# Assumes a working euphoria installation

!include config.wat

CREOLEHTML= creole.e filreadr.e html_gen.e kanarie.e seqreadr.e txtreadr.e

!ifndef PREFIX
PREFIX=$(%EUDIR)
!endif

all : .SYMBOLIC build\creole.exe

build\main-.c build\creole.mak : creole.ex $(CREOLEHTML)
	-mkdir build
	cd build
	euc -makefile -con ..\creole.ex
	cd ..

build\creole.exe : build\main-.c build\creole.mak
	 cd build
	$(MAKE) -f creole.mak
	cd ..

install : .SYMBOLIC
	copy build\creole.exe $(PREFIX)\bin\

uninstall : .SYMBOLIC 
	-del $(PREFIX)\bin\creole.exe

clean : .SYMBOLIC 
	-del /S /Q build

distclean : .SYMBOLIC clean
	-del Makefile config.wat

# Makefile for building and installing eudoc
# Assumes a working euphoria installation

!include config.wat

!ifndef PREFIX
PREFIX=$(%EUDIR)
!endif
 
all : .SYMBOLIC build\creole.exe

# Because when build/main-.c and build/creole.exe are built the timestamp for the directory 
# will be updated, we need to specify that we only care if build exists and not if it has a 
# timestamp newer than the targets it contains.   
build : .existsonly
	mkdir build

build\main-.c build\creole.mak : build creole.ex $(CREOLEHTML)
	cd build
	euc -wat -makefile -con ..\creole.ex
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

# remove intermediate files without marking things as out of date. 	
# wmake will do nothing unless source are changed.
mostlyclean : .SYMBOLIC
	-del build\*.obj
	
distclean : .SYMBOLIC clean
	-del Makefile config.wat

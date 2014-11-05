#!/bin/bash
set -e

parallel=`grep -c ^processor /proc/cpuinfo`
host=`head -1 /etc/issue`

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TOP=$dir/../..
OUT=$TOP/out/win64/
[[ ! -d $OUT ]] && mkdir -p $OUT
libdir=$dir/externals

if [[ "Fedora release 20 (Heisenbug)" == "$host" ]]
then
	toolchain_file=$dir/fedora20/toolchain_mingw64.cmake
	hostdir=$dir/fedora20/
else
	toolchain_file=$dir/toolchain_mingw64.cmake
fi
. $hostdir/env.sh

#Build dependancies
# irrlicht
cd $OUT
if [ ! -f "_externals/irrlicht/bin/Win64-gcc/Irrlicht.dll" ]
then
	mkdir -p _externals/irrlicht/bin/Win64-gcc
	mkdir -p _externals/irrlicht/lib/Win64-gcc
	cp -r $TOP/external/irrlicht/* _externals/irrlicht/
	cd _externals/irrlicht/source/Irrlicht/
	sed -i 's/Win32-gcc/Win64-gcc/g' Makefile Irrlicht-gcc.cbp Irrlicht.dev
	sed -i 's/ld3dx9d/ld3dx9_43/g' Makefile
	sed -i 's/-DNO_IRR_COMPILE_WITH_DIRECT3D_9_//' Makefile
	# BUG in d3d9.h (mingw64)
	# http://sourceforge.net/p/mingw-w64/bugs/409/
	sed -i 's/D3DPRESENT_LINEAR_CONTENT/0x00000002L/g' CD3D9Driver.cpp
	make win32
fi

#leveldb
cd $OUT
if [ ! -f "_externals/leveldb/bin/libleveldb.dll" ]
then
	mkdir -p _externals/leveldb/bin/
	mkdir -p _externals/leveldb/lib/
	cp -r $TOP/external/leveldb/* _externals/leveldb/
	cd _externals/leveldb/
	TARGET_OS=OS_WINDOWS_CROSSCOMPILE CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ AR=x86_64-w64-mingw32-ar \
        make libleveldb.a libleveldb.dll
	mv libleveldb.a libleveldb.dll.a lib/
	mv libleveldb.dll bin/
fi

# Build the thing
cd $TOP/minetest
git_hash=`git show | head -c14 | tail -c7`
cd $OUT
[ -d _build ] && rm -Rf _build/
mkdir _build
cd _build
cmake $TOP/minetest \
	-DCMAKE_TOOLCHAIN_FILE=$toolchain_file \
	-DCMAKE_INSTALL_PREFIX=/tmp \
	-DVERSION_EXTRA=$git_hash \
	-DBUILD_CLIENT=1 -DBUILD_SERVER=0 \
	\
	-DENABLE_SOUND=1 \
	-DENABLE_CURL=1 \
	-DENABLE_GETTEXT=1 \
	-DENABLE_FREETYPE=1 \
	-DENABLE_LEVELDB=1 \
	\
	-DIRRLICHT_INCLUDE_DIR=$OUT/_externals/irrlicht/include \
	-DIRRLICHT_LIBRARY=$OUT/_externals/irrlicht/lib/Win64-gcc/libIrrlicht.a \
	-DIRRLICHT_DLL=$OUT/_externals/irrlicht/bin/Win64-gcc/Irrlicht.dll \
	\
	-DZLIB_INCLUDE_DIR=$libdir/zlib/include \
	-DZLIB_LIBRARIES=$libdir/zlib/lib/libz.dll.a \
	-DZLIB_DLL=$libdir/zlib/bin/zlib1.dll \
	\
	-DLUA_INCLUDE_DIR=$libdir/luajit/include \
	-DLUA_LIBRARY=$libdir/luajit/libluajit.a \
	\
	-DOGG_INCLUDE_DIR=$libdir/libogg/include \
	-DOGG_LIBRARY=$libdir/libogg/lib/libogg.dll.a \
	-DOGG_DLL=$libdir/libogg/bin/libogg-0.dll \
	\
	-DVORBIS_INCLUDE_DIR=$libdir/libvorbis/include \
	-DVORBIS_LIBRARY=$libdir/libvorbis/lib/libvorbis.dll.a \
	-DVORBIS_DLL=$libdir/libvorbis/bin/libvorbis-0.dll \
	-DVORBISFILE_LIBRARY=$libdir/libvorbis/lib/libvorbisfile.dll.a \
	-DVORBISFILE_DLL=$libdir/libvorbis/bin/libvorbisfile-3.dll \
	\
	-DOPENAL_INCLUDE_DIR=$libdir/openal_stripped/include/AL \
	-DOPENAL_LIBRARY=$libdir/openal_stripped/lib/libOpenAL32.dll.a \
	-DOPENAL_DLL=$libdir/openal_stripped/bin/OpenAL32.dll \
	\
	-DCURL_DLL=$libdir/libcurl/bin/libcurl-4.dll \
	-DCURL_INCLUDE_DIR=$libdir/libcurl/include \
	-DCURL_LIBRARY=$libdir/libcurl/lib/libcurl.dll.a \
	\
	-DFREETYPE_INCLUDE_DIR_freetype2=$libdir/freetype/include/freetype2 \
	-DFREETYPE_INCLUDE_DIR_ft2build=$libdir/freetype/include/freetype2 \
	-DFREETYPE_LIBRARY=$libdir/freetype/lib/libfreetype.dll.a \
	-DFREETYPE_DLL=$libdir/freetype/bin/libfreetype-6.dll \
	\
	-DLEVELDB_INCLUDE_DIR=$OUT/_externals/leveldb/include \
	-DLEVELDB_LIBRARY=$OUT/_externals/leveldb/lib/libleveldb.dll.a \
	-DLEVELDB_DLL=$OUT/_externals/leveldb/bin/libleveldb.dll \
	\
	-DCUSTOM_GETTEXT_PATH=$libdir/gettext \
	-DGETTEXT_MSGFMT=`which msgfmt` \
	-DGETTEXT_DLL=$libdir/gettext/bin/libintl-8.dll \
	-DGETTEXT_ICONV_DLL=$libdir/gettext/bin/libiconv-2.dll \
	-DGETTEXT_INCLUDE_DIR=$libdir/gettext/include \
	-DGETTEXT_LIBRARY=$libdir/gettext/lib/libintl.dll.a

make package -j$parallel

# EOF

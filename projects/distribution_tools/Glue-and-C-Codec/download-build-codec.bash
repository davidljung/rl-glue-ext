#!/bin/bash
INSTALLDIR=`pwd`/install_root/usr/local
rm -Rf codec-trunk
svn export http://rl-glue-ext.googlecode.com/svn/trunk/projects/codecs/C/ codec-trunk
cd codec-trunk
#Disable shared so that we can package them up and relocate the libraries.
./configure --prefix=$INSTALLDIR --with-rl-glue=$INSTALLDIR --disable-shared && make && make install
cd ..


#!/bin/sh
#
# This file should remain OS independent
#
# $Id: bootstrap.sh,v 1.1 2012/01/23 18:17:09 nadya Exp $
#
# @Copyright@
# @Copyright@
#
# $Log: bootstrap.sh,v $
# Revision 1.1  2012/01/23 18:17:09  nadya
# initial
#
#

. ../etc/bootstrap-functions.sh


compile_and_install hdf5
#compile_and_install caddrc
/sbin/ldconfig

#install_os_packages caddrc 
#compile_and_install fltk
#compile_and_install netcdf
#compile_and_install openbabel

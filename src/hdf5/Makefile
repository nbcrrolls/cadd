#
# $Id: Makefile,v 1.1 2012/01/23 18:17:10 nadya Exp $
#
# @Copyright@
# @Copyright@
#
# $Log: Makefile,v $
# Revision 1.1  2012/01/23 18:17:10  nadya
# initial
#
#

PKGROOT		= /opt/cadd/hdf5
REDHAT.ROOT     = $(CURDIR)/../../
-include $(ROCKSROOT)/etc/Rules.mk
include Rules.mk

HDF5FILES = bin  COPYING  include  lib  README  RELEASE.txt  share

build:
	gunzip -c $(NAME)-$(VERSION)-$(EXT).tar.gz | $(TAR) -xf -
	cd patch-files && find . -type f | grep -v CVS | cpio -pduv ../
	
install::
	mkdir -p $(ROOT)/$(PKGROOT)
	mkdir -p $(ROOT)/etc/ld.so.conf.d
	echo $(PKGROOT)/lib > $(ROOT)/etc/ld.so.conf.d/hdf5.conf
	(                                              \
		cd $(NAME)-$(VERSION)-$(EXT);          \
		cp -p -r $(HDF5FILES)  $(ROOT)/$(PKGROOT); \
	)

clean::
	rm -rf $(NAME)-$(VERSION)

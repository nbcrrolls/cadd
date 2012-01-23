#
# $Id: Makefile,v 1.1 2012/01/23 18:17:09 nadya Exp $
#
# @Copyright@
# @Copyright@
#
# $Log: Makefile,v $
# Revision 1.1  2012/01/23 18:17:09  nadya
# initial
#
#

PKGROOT		= /opt/cadd/fltk
REDHAT.ROOT     = $(CURDIR)/../../
-include $(ROCKSROOT)/etc/Rules.mk
include Rules.mk


build:
	gunzip -c $(NAME)-$(VERSION)-source.tar.gz | $(TAR) -xf -
	(								\
		cd $(NAME)-$(VERSION);					\
		./configure --prefix=$(PKGROOT);\
	)
	

install::
	mkdir -p $(ROOT)/$(PKGROOT)
	(								\
		cd $(NAME)-$(VERSION);					\
		make DESTDIR=$(ROOT) install			\
	)

clean::
	rm -rf $(NAME)-$(VERSION)

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

SRCDIRS = `find . -type d -maxdepth 1 -not -name CVS -not -name .`

default:	rpm

copyright rpm pkg clean::
	for i in $(SRCDIRS) ; do \
		(cd $$i; make $@) ; \
	done


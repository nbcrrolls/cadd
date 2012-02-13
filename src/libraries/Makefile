#
# $Id: Makefile,v 1.3 2012/02/13 22:40:40 clem Exp $
#
# @Copyright@
# @Copyright@
#
# $Log: Makefile,v $
# Revision 1.3  2012/02/13 22:40:40  clem
# Updated the libraries, still waiting for Rommie for the NCI_DS3
#
# Revision 1.2  2012/01/31 20:43:33  clem
# minor fixes to the cadd roll
#
# Revision 1.1  2012/01/28 03:20:00  clem
# First round of fixes to the vina autodock screening scritp,
# still a lot of work to do.
# First version of the screening library
#
# Clem
#
# Revision 1.1  2012/01/24 03:41:02  nadya
# initial
#
#

CADDROLL        = /state/partition1/opal
PKGROOT		= $(CADDROLL)/libraries
LIBRARIES	= NCIDS_SC sample
REDHAT.ROOT     = $(CURDIR)/../../
-include $(ROCKSROOT)/etc/Rules.mk
include Rules.mk


build: 


install::
	mkdir -p $(ROOT)/$(PKGROOT);
	for library in $(LIBRARIES); do\
		tar -xvzf $$library.tar.gz -C $(ROOT)/$(PKGROOT);\
	done


clean::
	echo
	

#! /usr/bin/env python

import os
import sys
import string
import getopt
import types
import UserDict
import re
from pprint import pprint
import zipfile
import gzip

class Struct:
    """ base structure """
    pass

class TrajQR:
    """ Base class for trajectory files creation """
    def __init__(self, argv):
        self.args = argv[1:]
        self.usageName  = os.path.basename(argv[0])

        self.setDefaults()
        self.checkTclFile()
        self.parseArgs()
        self.checkArgs()

    def setDefaults(self):
        """ set default class attributes """
        self.setDefaultOpts()

	self.format = None                        # input file format, zip or gz
	self.fnames = None		          # list of pdb files from input compressed file
        self.default_structFile = "qr.struct"     # default filename for output QR structures 
        self.default_treeFile   = "qh.tree"       # default filename for output QH tree
        self.tclFile = "/opt/cadd/bin/trajQR.tcl" # tcl file to use with vmd
	self.vmdDefOpts = "/opt/vmd/bin/vmd -dispdev text -e %s " % self.tclFile  # start of vmd command

	# for user input
        self.input      = None          # compressed pdbs file name
        self.rmsd       = None          # rmsd cutoff
        self.structFile = None          # filename for output QR structures 
        self.treeFile   = None          # filename for output QH tree


    def setDefaultOpts(self):
        """ set default command line options """
        self.getopt = Struct()
        self.getopt.s = ['h']
        self.getopt.l = ['help']

        self.getopt.s.extend([('f:', 'file'),
                              ('r:', 'rmsd'),
                              ('s:', 'struct'),
                              ('t:', 'tree')
                              ])
        self.getopt.l.extend([('file=', 'file'),
                              ('rmsd=', 'rmsd'),
                              ('struct=', 'struct'),
                              ('tree=', 'tree')
                              ])

    def checkTclFile(self):
        """ check if tcl file is present """
        if not os.path.isfile(self.tclFile) :
            self.inputError = "Required tcl file %s is missing" % self.tclFile
            self.inputErrExit()

    def parseArg(self, c):
        """ parse single command line argument """
        if c[0] in ('-h', '--help'):
            self.help()
        elif c[0] in ('-f', '--file'):
            self.input = c[1]
        elif c[0] in ('-r', '--rmsd'):
            self.rmsd = c[1]
        elif c[0] in ('-s', '--struct'):
            self.structFile = c[1]
        elif c[0] in ('-t', '--tree'):
            self.treeFile = c[1]
        else:
            return 0

        return 1

    def parseArgs(self):
        """ parse command line arguments """
        short = ''
        for e in self.getopt.s:
            if type(e) == types.TupleType:
                short = short + e[0]
            else:
                short = short + e

        long = []
        for e in self.getopt.l:
            if type(e) == types.TupleType:
                long.append(e[0])
            else:
                long.append(e)
        try:
            opts, args = getopt.getopt(self.args, short, long)
        except getopt.error:
            self.help()

        for c in opts:
            self.parseArg(c)
        self.args = args

    def checkArgs(self):
        """ check correctness of command line arguments """
        missing = 0;
        self.inputError = "ERROR in input:\n"
        if self.input == None: 
            self.inputError += ('\tmissing compressed file consiting of the input PDB files \n')
            missing += 1
        if self.rmsd == None: 
            self.inputError += ('\tmissing rmsd cutoff (float) \n')
            missing += 1
        if missing:
            self.inputErrExit()

        if self.structFile == None:
            self.structFile = self.default_structFile
        if self.treeFile == None:        
            self.treeFile = self.default_treeFile

	self.checkInputFile()    
	self.checkRMSD()    
	self.checkOutputFile()    

    def runVMDcommand(self):
	self.command = self.vmdDefOpts + " -args %s %s %s %s " % (self.pdbDir, self.rmsd, self.structFile, self.treeFile)
	print "Executing VMD command: %s" % self.command
	os.system(self.command)

    def checkOutputFile(self):
	""" validate output files names """
        # validate output QR filename
        msgStruct = "filename for output QR structures"
        self.structFile = self.checkValidFileName(self.default_structFile, self.structFile, msgStruct)

        # validate output QH tree filename
        msgTree = "filename for output QH tree"
        self.treeFile = self.checkValidFileName(self.default_treeFile, self.treeFile, msgTree)

    def checkInputFile(self):
	""" Checks if file is zip or gzip type and checks its content names """
	f = os.popen('file -bi %s' % self.input, 'r')
	info = f.read()
	f.close()

        # check archive format
	if  string.find (info, 'x-zip') > -1:
		self.checkZipFile()
	elif string.find (info, 'x-gzip') > -1:
		self.checkGzipFile()
	elif string.find (info, 'ERROR') > -1:
            self.inputError = info
            self.inputErrExit()
	else:
            self.inputError += "\tCompressed file %s is not in zip or gzip format" % self.input
            self.inputErrExit()

	# set dir name from the first entry in the archive
	self.pdbDir, discard = os.path.split(self.fnames[0])

        # check archive content
        fileNameError = 0
        for name in self.fnames : 
            if self.checkFileNameStart(name) :
                self.inputError += "\tfile name in compressed arhive cannot start with '/' or '..': %s\n" % name
                fileNameError += 1
	    # verify archive directory name
	    dir, discard = os.path.split(name)
	    if self.pdbDir != dir:
                self.inputError += "\tCompressed file %s does not uncompress into a single directory" % self.input
                self.inputErrExit()

        if fileNameError:
            self.inputError += "Please correct errors in your %s arhive. \n" % self.input 
            self.inputErrExit()

	if self.pdbDir == '' :
	    self.pdbDir = '.'

	# uncompresss archive
	self.uncompressInputFile()

    def checkFileNameStart(self, str):
	""" returns 1 if an input string starts with '..' or '/', otherwise returns 0 """
        result = 0
        if str.startswith('..'):
            result = 1
        if str.startswith('/'):
            result = 1
	return result

    def checkZipFile(self):
	""" check zip file contents list """
	if zipfile.is_zipfile(self.input) == True :
            zf = zipfile.ZipFile(self.input, 'r')
            self.fnames =  zf.namelist()
	    self.format = "zip"
	    zf.close()
        else: 
	    self.inputError += "\tCompressed zip file %s does not uncompress properly." % self.input
            self.inputErrExit()

    def checkGzipFile(self):
	""" check gzip file contents list """
	try: # compressed
		#gzip.GzipFile(self.input, 'r')
		f = os.popen('tar tf %s' % (self.input), 'r')
		info = f.read()
		f.close()
		self.fnames = info.splitlines()
		self.format = "gzip"
	except: # not compressed
	    self.inputError += "\tCompressed gzip file %s does not uncompress properly." % self.input
            self.inputErrExit()

    def uncompressInputFile(self): 
	""" uncompress input file """
	if self.format == "zip":
		f = os.popen('unzip %s' % (self.input), 'r')
		info = f.read()
		f.close()
	elif self.format == "gzip":
		f = os.popen('gunzip -c %s | tar xf -' % (self.input), 'r')
		info = f.read()
		f.close()
	else :
	    self.inputError += "Wrong file format %s." % self.input
            self.inputErrExit()

    def inputErrExit(self):
        """ prints input related error and exits """
        print (self.inputError)
        sys.exit(0)

    def help(self):
        """ print usage """
        print '\nNAME: \n' , \
              '\t%s - run TrajQR clustering on a set of pdb files\n' % self.usageName, \
              '\nSYNOPSIS:\n' , \
              '\t%s -f FILE -r NUM [-s QRstruct] [-t QHtree]  [-h|help]\n' % self.usageName, \
              '\nDESCRIPTION:\n' , \
              '    -f|--file FILE       - compressed file of the input PDB files (files.zip or files.tar.gz).\n', \
              '                           Example 1a.tar.gz, untars into a list of files. \n', \
              '    -r|--rmsd NUM        - float RMSD cutoff. Examle: 0.5 \n', \
              '    -s|--struct QRstruct - filename for output QR structures list. Default: qr.struct\n', \
              '    -t|--tree QHtree     - filename for output QH tree. Default: qh.tree\n', \
              '    -h|--help            - prints usage\n', \
        sys.exit(0)


    def checkRMSD(self):
        """ check if RMSD is float """
        try:
            self.rmsd = float(self.rmsd)
        except:
	    self.inputError += "\tRMSD cutoff is not a float: %s " % self.rmsd
            self.inputErrExit()

    def checkValidFileName(self, defname, name, err, NAME_MAX=255):
        """ check output file name validity """
	strip_name = os.path.basename(name)  # strip / and . from the front
        length = len(strip_name)

        if length == 0 :
            print "WARNING:\t '%s' %s is too short, will use default '%s' " % (name, err, defname)
            return defname

        if length >=NAME_MAX :
            print "WARNING:\t '%s' %s is too long, will use default '%s' " % (name, err, defname)
            return defname

        valid_chars = "-_.%s%s" % (string.ascii_letters, string.digits)
        valid_name = ''.join(c for c in strip_name if c in valid_chars)
        if name != valid_name:
            print "WARNING:\t '%s' filename contains invalid characters, will use '%s' " % (name, valid_name)
        return valid_name

    def fixPdbAlignment(self):
	"""temp fix for VMD 1.9 MultiSeq problem. Change HSD, HSE, and HSP to HIS in input pdb files 
	   Remove this function when a fix for vmd is available.
	"""
	sedCommand = "sed -i 's/HSD/HIS/;s/HSE/HIS/;s/HSP/HIS/' %s" 
        for name in self.fnames : 
        	if not os.path.isfile(name) : continue
		os.system(sedCommand % name)

    def run(self):
        """ main function """
	self.fixPdbAlignment()
        self.runVMDcommand()
	print self.command

        sys.exit(0);


    def test(self):
        """ test """
        pprint (self.__dict__)


if __name__ == "__main__":
        app=TrajQR(sys.argv)
        app.run()


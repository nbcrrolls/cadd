#! /usr/bin/env python

import os
import sys
import string
import getopt
import types
import UserDict
import re
from pprint import pprint

class Struct:
    """ base structure """
    pass

class Traj:
    """ Base class forr trajewctory files creation """
    def __init__(self, argv):
        self.args = argv[1:]
        self.usage_command  = os.path.basename(argv[0])

        self.setDefaults()
        self.parseArgs()
        self.checkArgs()

    def setDefaults(self):
        """ set default class attributes """
        self.setDefaultOpts()

        self.input = None          # input trajectory file name
        self.active = None         # input active site residue file name
        self.base = None           # base name of the input file
        self.output = None         # base name of the output file
        self.ext = None            # extension name of the input file

        self.trajFile = None       # output trajectory file name
        self.trajText = ""         # file text 

        self.fftrajFile = None     # output first frame trajectory file name
        self.fftrajText = ""       # file text 

        self.selFile = None        # output selections file name
        self.selText = ""          # file text

        self.pattIn = "END"        # word will be substituted
        self.pattOut = "ENDMDL"    # sustitute word
        self.header = "CRYST1"     # header lines to remove


    def setDefaultOpts(self):
        """ set default command line options """
        self.getopt = Struct()
        self.getopt.s = ['h']
        self.getopt.l = ['help']

        self.getopt.s.extend([('t:', 'traj'),
                              ('a:', 'active'),
                              ('p:', 'prefix')
                              ])
        self.getopt.l.extend([('traj=', 'trajectory'),
                              ('active=', 'active'),
                              ('prefix=', 'prefix')
                              ])

    def parseArg(self, c):
        """ parse single command line argument """
        if c[0] in ('-h', '--help'):
            self.help()
        elif c[0] in ('-t', '--traj'):
            self.input = c[1]
        elif c[0] in ('-a', '--active'):
            self.active = c[1]
        elif c[0] in ('-p', '--prefix'):
            self.output = c[1]
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
        if self.input == None:
            self.help()
            
        self.base, self.ext = os.path.splitext(self.input)
        if self.output == None:
            self.output = self.base
        self.trajFile = self.output + "-traj" + self.ext
        self.fftrajFile = self.output + "-fftraj" + self.ext
        self.selFile = self.output + "-selections.ndx"


    def help(self):
        """ print usage """
        print '\n', \
              'USAGE: %s -t file1 -a file2 [-p str] [-h|help]\n' % self.usage_command, \
              '    -t file1 - input trajectory pdb file. Examle: apo-fr.pdb \n', \
              '    -a file2 - input active site residue pdb file. Examle: apo-fr.pdb \n', \
              '    -p str  - base name to use for output files. Example: -p abc will create\n', \
              '               (1) abc-traj.pdb: trajectory output file \n',\
              '               (2) abc-fftraj.pdb: first frame of trajectory file\n',\
              '               (3) abc-selection.ndx: atom selection file\n',\
              '               If this option is omitted, base name of file1 is used\n',\
              '    -h|--help - print usage\n', \
              '\nPurpose: prepare GROMOS clustering files: tarjectory, first frame and atom selection\n'
        sys.exit(0)


    def readFile(self, name):
        """ read input file """
        try:
            f = open(name, 'r')
            content = f.read()
            f.close()
        except IOError:
            print "Error reading file %s" % name
            return None
    
        return content


    def writeFile(self, name, text):
        """ write output file """
        if text == None:
            print "Error: no text to write file %s" % name
            return
        
        try:
            f = open(name, 'w')
            f.write (text)
            f.close()
        except IOError:
            print "Error writing file %s" % name


    def readRawTraj(self):
        text = self.readFile(self.input)
        text = text.replace(self.pattIn, self.pattOut)
        text = self.removeEmptyLine(text)
        text = self.removeLines(text, self.header)
        self.trajText = text

    def readRawActiveSite(self):
        if self.active == None: return
        text = self.readFile(self.active)
        text = self.removeLines(text, self.header)
        text = self.removeLines(text, self.pattIn)
        text = self.removeEmptyLine(text)

        indices = []
        lines = text.splitlines()
        for l in lines:
            words = l.split()
            if words[5] not in indices:
                indices.append(words[5])

        indices.sort(lambda a,b: cmp(int(a), int(b)))
        self.indices = indices

    def chooseActiveSiteResidue(self):
        activeSiteAtomIndices = []
        alphaCarbonIndices = []
        text = self.fftrajText
        text = self.removeLines(text, self.header)
        text = self.removeLines(text, self.pattIn)
        text = self.removeEmptyLine(text)
        lines = text.splitlines()
        for l in lines:
            words = l.split()
            if words[5] in self.indices:
                activeSiteAtomIndices.append(words[1]) 
            if  "CA" in words:
                alphaCarbonIndices.append(words[1])

        alphaCarbonText = self.formatIndicesPrint("[ C-alpha ]", alphaCarbonIndices) +  os.linesep + os.linesep
        activeSiteText = self.formatIndicesPrint("[ active_site ]", activeSiteAtomIndices) + os.linesep + os.linesep
        self.selText = alphaCarbonText + activeSiteText 


    def formatIndicesPrint(self, header, indices):
        """ ndx-format indices """
        numInRow = 15
        str = header
        for i in range(len(indices)):
            if i % numInRow == 0:
                str += os.linesep
                str += "%4s" % indices[i]
            else:
                str +=  " %4s" % indices[i]
        return str


    def prepareTrajFiles(self):
        """ create trajectory and first frame pdb files"""
        # read raw trajectory file
        self.readRawTraj()

        # create a trajectory pdb file
        self.writeFile(self.trajFile, self.trajText)

        # create a first frame trajectory pdb file
        self.fftrajText = self.trajText[:self.trajText.index(self.pattOut) + len(self.pattOut)]
        self.writeFile(self.fftrajFile, self.fftrajText)


    def prepareAtomSelectionFIle(self):
        """ create atom selection ndx file"""
        if self.active == None: return
        self.readRawActiveSite()
        self.chooseActiveSiteResidue()
        self.writeFile(self.selFile, self.selText)


    def removeLines (self, text, word):
        """ remove lines lines containing text defined in self. header"""
        newtext = filter(lambda x:x[:len(word)]!=word, text.splitlines())
        return  os.linesep.join(newtext)


    def removeEmptyLine (self, text):
        """ remove empty lines and lines containing only spaces """
        newtext = filter(str.strip, text.splitlines()) 
        return  os.linesep.join(newtext)


    def run(self):
        """ main function """
        self.prepareTrajFiles()
        self.prepareAtomSelectionFIle()
        sys.exit(0);


    def test(self):
        """ test """
        pprint (self.__dict__)


if __name__ == "__main__":
        app=Traj(sys.argv)
        app.run()



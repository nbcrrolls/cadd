#!/share/apps/python2.6/bin/python

import os
import os.path
import sys

class  ResultSummary:

    def __init__(self, argv):
        self.usageName = os.path.basename(argv[0])
        if len(argv) < 2:
            self.help()
        self.workdir = argv[1]

        self.checkArgs()
        self.setDefaults()

    def checkArgs(self):
        if not os.path.isdir(self.workdir):
            sys.exit('ERROR: %s is not a directory' % self.workdir)
        if not  self.workdir.endswith("/") :
            self.workdir = self.workdir + "/"

    def help (self):
        """ print usage """
        print 'Usage: %s workingdir\n' % self.usageName, \
              'Workingdir is a directory \n'
        sys.exit(0)


    def setDefaults(self):
        self.listing = os.listdir(self.workdir)
        self.searchStr = '.log'
        self.allLogs = []
        self.outFile = self.workdir + "screen_result_summary.log"
        print "Results summary file: %s" % self.outFile
        self.lineNum = 28 # lines of header to skip


    def HasLog (self, dir):
        fullPath = os.path.join(self.workdir,dir)
        logs = filter(lambda x: x.endswith(self.searchStr), os.listdir(fullPath))
        if len(logs):
            map(lambda x: self.GetFileContent(fullPath, dir, x),logs)
            return True
        else:
            return False

    def GetFileContent (self, path, dir, log):
        file = os.path.join (path, log)
        if os.path.isfile (file):
                f = open(file)        
                lines = f.readlines()
                if lines[0].find("parse error") > -1 :
                    print "Config file parse error for %s" % dir
                    return
                f.close()
                try:
                    str = dir + " " + lines[self.lineNum]
                    parts = str.split()
                    self.allLogs.append(parts)
                except IndexError: 
                    pass

    def writeFile(self, info):
        out = open(self.outFile, 'w')
        out.write(''.join(info))
        out.close()

    def run(self):
        folders = filter(lambda x: os.path.isdir(os.path.join(self.workdir,x)),self.listing)
        files = filter(lambda y: self.HasLog(y), folders)
        self.allLogs.sort(key = lambda tup: float(tup[2]) )
        finalList = list('%s%5s%12s%10s%10s\n' % tuple(item) for item in self.allLogs )

        self.writeFile(finalList)

if __name__ == "__main__":
        app = ResultSummary(sys.argv)
        app.run()


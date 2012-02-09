# University of Illinois Open Source License
# Copyright 2007 Luthey-Schulten Group, 
# All rights reserved.
# 
# Developed by: Luthey-Schulten Group
# 			    University of Illinois at Urbana-Champaign
# 			    http://www.scs.uiuc.edu/~schulten
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the Software), to deal with 
# the Software without restriction, including without limitation the rights to 
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
# of the Software, and to permit persons to whom the Software is furnished to 
# do so, subject to the following conditions:
# 
# - Redistributions of source code must retain the above copyright notice, 
# this list of conditions and the following disclaimers.
# 
# - Redistributions in binary form must reproduce the above copyright notice, 
# this list of conditions and the following disclaimers in the documentation 
# and/or other materials provided with the distribution.
# 
# - Neither the names of the Luthey-Schulten Group, University of Illinois at
# Urbana-Champaign, nor the names of its contributors may be used to endorse or
# promote products derived from this Software without specific prior written
# permission.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL 
# THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS WITH THE SOFTWARE.
#
# Author(s): Elijah Roberts

package require blast 1.1
package require clustalw 1.1
package require upgma_cluster 1.2
package require libbiokit 1.1
package require multiseqdialog 1.1
package require phylotree 1.1
package require seqdata 1.1
package require stamp 1.2

proc initializeMultiSeqEnvironment {} {
    
    global env
    global tempDir
    global filePrefix
    global multiSeqEnvironmentInitialized
    
    if {![info exists multiSeqEnvironmentInitialized]} {
    
        set multiSeqEnvironmentInitialized 1
        set tempDir $env(TMPDIR)
        set filePrefix "vmd-[lindex [split [expr rand()] .] 1]"
        
        # Load the multiseq rc file.
        ::MultiSeqDialog::loadRCFile
    
        # Set up some packages.
        ::MultiSeqDialog::setTempFileOptions $tempDir $filePrefix
        ::MultiSeqDialog::setArchitecture [vmdinfo arch]
        ::Blast::setBlastProgramDirs [::MultiSeqDialog::getDirectory "blast"] [::MultiSeqDialog::getVariable "blast" "BLASTMAT"] [::MultiSeqDialog::getVariable "blast" "BLASTDB"]
        ::Blast::setTempFileOptions $tempDir $filePrefix
        ::Blast::setArchitecture [vmdinfo arch]

        ::ClustalW::setTempFileOptions $tempDir $filePrefix       
        ::ClustalW::setArchitecture [vmdinfo arch]
        ::UPGMA_Cluster::setTempFileOptions $tempDir $filePrefix       
        ::Libbiokit::setTempFileOptions $tempDir $filePrefix
        ::STAMP::setTempFileOptions $tempDir $filePrefix
        ::STAMP::setArchitecture [vmdinfo arch]
    }
}

proc cleanupMultiSeqEnvironment {} {
    
    global tempDir
    global filePrefix
    
    # Delete any files with the temp prefix.
    foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
        if {[file exists $file]} {
            file delete -force $file
        }
    }   
}

proc applyStampTransformations {structureIDs} {

    array set viewrot [::STAMP::getRotations]
    array set viewtrans [::STAMP::getTransformations]
    
    # Save the viewpoint first -- just in case we need to get it back.
    saveViewpoint
    
    for {set i 0} {$i < [llength $structureIDs]} {incr i} {

        set transformationMatrix {}
        
        for {set j 0} {$j < 3} {incr j} {
            lappend transformationMatrix [concat [lindex $viewtrans($i) $j] [lindex $viewrot($i) $j]]
        }
        lappend transformationMatrix {0.000000 0.000000 0.000000 1.0000000}
        
        # Move the atoms.
        set molID [lindex [::SeqData::VMD::getMolIDForSequence [lindex $structureIDs $i]] 0]
        set atoms [atomselect $molID "all"]  
        $atoms move $transformationMatrix
        $atoms delete
    }
}

proc crossReferenceTreeByIndex {treeID sequenceIDs} {
    
    # Import global variables.
    variable treeNodeToSequenceIDMap
    variable sequenceIDToTreeNodeMap
    
    # Get the leaf nodes.
    set leafNodes [::PhyloTree::Data::getLeafNodes $treeID [::PhyloTree::Data::getTreeRootNode $treeID]]
    
    # Assign the properties to the nodes using the node name as the index into the list.
    foreach node $leafNodes {
        
        set nodeName [::PhyloTree::Data::getNodeName $treeID $node]
            
        # Get the sequence id and name.
        set sequenceID [lindex $sequenceIDs $nodeName]
        set sequenceName [::SeqData::getName $sequenceID]
        
        # Replace the node name and set any node attributes.
        ::PhyloTree::Data::setNodeName $treeID $node $sequenceName
    }
}


#### Start of the main part of the script ####

# Parse the command line arguments.
if {[llength $argv] < 4} {
    puts ""
    puts "Usage: structure_dir rmsd_cutoff qr_set_filename qh_tree_filename"
    quit
}
set structureDir [lindex $argv 0]
set rmsdCutoff [lindex $argv 1]
set qrFilename [lindex $argv 2]
set treeFilename [lindex $argv 3]

# Initialize up the MultiSeq environment.
initializeMultiSeqEnvironment

# Load the structures.
set structureFilenames [glob "$structureDir/*.pdb"]
foreach structureFilename $structureFilenames {
    mol new $structureFilename type pdb waitfor all
}
puts "INFO) Loaded [llength $structureFilenames] structures."

# Get the sequence ids for all of the structures.
set sequenceIDs [lindex [::SeqData::VMD::updateVMDSequences] 0]
if {[llength $sequenceIDs] != [llength $structureFilenames]} {
    puts "ERROR) Could not get sequences for laoded structures."
}

# Align the structures using stamp.
set npassDefault 2
set scanDefault 1
set scanscoreDefault 6
set scanslideDefault 5
set slowscanDefault 0
set sequenceIDs [::STAMP::alignStructures $sequenceIDs $scanDefault $scanslideDefault $scanscoreDefault $slowscanDefault $npassDefault]
puts "INFO) Aligned structures."

# Generate the QH tree
set qhMatrix [::Libbiokit::getPairwiseQH $sequenceIDs]
set qhTreeData [::UPGMA_Cluster::createUPGMATree $qhMatrix]
set treeID [::PhyloTree::JE::loadTreeData "QH" $qhTreeData]
crossReferenceTreeByIndex $treeID $sequenceIDs
::PhyloTree::Newick::saveTreeFile $treeFilename $treeID
puts "INFO) Generated QH tree of structures: $treeFilename"

# Generate the QH tree image
puts "INFO) begin"
::PhyloTree::addTrees [::PhyloTree::Newick::loadTreeFile $treeFilename]
puts "INFO) end"

# Get the QR set.
set qrSequenceIDs [::Libbiokit::getNonRedundantStructures $sequenceIDs $rmsdCutoff 0 "rmsd"]
set qrFp [open $qrFilename "w"]
foreach qrSequenceID $qrSequenceIDs {
    puts $qrFp "[::SeqData::getName $qrSequenceID]"
}
close $qrFp
puts "INFO) Generated QR set containing [llength $qrSequenceIDs] structures: $qrFilename"

# Clean up the MultiSeq environment.
cleanupMultiSeqEnvironment

# Exit VMD.
quit



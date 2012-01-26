#!/bin/bash

# this script extracts clusters from a pdb trajectory given a gromos output cluster.log file
# the output is in cluster_frames/

# start script from in directory with log file and insert trajectory path below
#pdbpath=/Your/path/here/trajectory.pdb
pdbpath=$1
path=$(pwd)
echo "$path"

#cat cluster.log | awk 'BEGIN{FS="|"}{if (NF==4) print $3}' | awk '{if ($1>0) print $1}' | grep -v "middle" |  awk '{printf "%i ",$1}' > clusterid
cat cluster.log | awk 'BEGIN{FS="|"}{if (NF==4) print $3}' | awk '{if ($1>-2) print $1}' | grep -v "middle" |  awk '{printf "%i ",$1+2}' > clusterid

count=0000

echo "extracting clusters"
cat clusterid

if [ ! -s clusterid ] ; then
   echo ""
   echo "ERROR: File clustserid is emprty. This means that g_gromos command did not finish properly. "
   echo "This may happen if you choose an RMSD cutoff that is too small, and all of the structures"
   echo "comprise their own cluster, the clustering algorithm will be unable to provide a working output."
   echo "If this happens, choose a larger cutoff and rerun the job."  
   exit
fi

mkdir frames
mkdir cluster_frames

cd frames
numlines=$(grep -n "END" $pdbpath | cut -d":" -f1 | head -n 1)

split -l "$numlines" -a 5 "$pdbpath"
ls -1 | sort | awk '{t=t+1;print "mv " $1 " frame_" (t-2) ".pdb"}' | csh

for i in `cat ""$path"/clusterid"`
do
old_i=`expr $i - 2`
let count++
#cp "$path"/frames/frame_"$i".pdb "$path"/cluster_frames/"$count"frame_"$i".pdb
cp "$path"/frames/frame_"$old_i".pdb "$path"/cluster_frames/"$count"frame_"$i".pdb
done



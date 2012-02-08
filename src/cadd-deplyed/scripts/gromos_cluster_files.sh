#!/bin/bash

SCREEN_BIN=/opt/cadd/bin/gromos_cluster_files
GROMACS_BIN=/opt/gromacs/bin
export LD_LIBRARY_PATH=/opt/openmpi/lib:$LD_LIBRARY_PATH

options=""
TRAJ="-traj.pdb"
FF="-fftraj.pdb"
SELECT="-selections.ndx"

while [ "$1" != "" ]; do
  case $1 in
             -traj) t=$2 ; shift 2 ;;
           -active) a=$2 ; shift 2 ;;
           -prefix) o=$2 ; shift 2;;
             -rmsd) cutoff=$2 ; shift 2 ;;
           -method) method=$2 ; shift 2 ;;
   default_options) options="$options $2" ; shift 2 ;;
    expert_options) options="$options $2" ; shift 2 ;;
                 *) options="$options $1" ; shift ;;
  esac
done

if test -z "$t"; then
  echo "ERROR: Trajectory input file is missing"
  exit 1
else
  ext=${t##*.}
  case $ext in
    pdb) ;;
    gz) gunzip $t ; t=${t%.*} ;;
  esac
fi

if test -z "$a" ; then
  echo "ERROR: Active site residue input file is missing"
  exit 1
else 
  ext=${a##*.}
  case $ext in
    pdb) ;;
    gz) gunzip $a ; a=${a%.*} ;;
  esac
fi

if test ! -z "$o"; then
  prefix="--prefix=$o"
  prefname=$o
else
  FILE=$t
  prefname=${FILE%.pdb}
fi

if test -z "$cutoff" ; then
  echo "ERROR: Rmsd cutoff is missing"
  exit 1
fi

CMD1="python $SCREEN_BIN/makeGromacsFiles.py --traj=$t --active=$a $prefix"
echo "Prepared to execute:  $CMD1"
$CMD1

CMD2="$GROMACS_BIN/g_cluster -n $prefname$SELECT -cutoff $cutoff -f $prefname$TRAJ -s $prefname$FF -method $method $options"
echo "Prepared to execute:  $CMD2"
echo "1 1" | $CMD2

cwd=`pwd`
#CMD3="$SCREEN_BIN/extract_central_members.sh $cwd/$t"
CMD3="$SCREEN_BIN/extract_central_members.sh $cwd/$prefname$TRAJ"
echo "Prepared to execute: $CMD3"
$CMD3

echo ""
echo ""
tarfile=JobOutputs-`date '+%Y%m%d-%s'`.tar
echo "NOTE: All result files are in $tarfile.gz"
tar cf $tarfile --exclude $tarfile --exclude $t --exclude $a .
gzip $tarfile



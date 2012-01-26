#!/bin/bash

MGLTOOLS_ROOT=/opt/mgltools
PYTHON=$MGLTOOLS_ROOT/bin/pythonsh
PREPARE_RECEPTOR=$MGLTOOLS_ROOT/MGLToolsPckgs/AutoDockTools/Utilities24/prepare_receptor4.py

args=""

while [ "$1" != "" ]; do
    if test "$1" = "-url"; then
      shift
      URL=$1
      name=`basename $URL`
      args=$args" -r $name "
    else     
      args=$args" "$1" "
    fi

    shift
done

echo CMD $cmd

if test ! -z $URL; then
  echo "Downloading $URL"
  wget $URL
  echo "Finished downloading $URL"
fi

cmd="$PYTHON $PREPARE_RECEPTOR $args"

echo "Going to execute $cmd"
$cmd


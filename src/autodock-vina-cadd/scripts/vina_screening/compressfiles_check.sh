#!/bin/bash

userlib=$1

if test -z "$userlib"; then 
  echo "No file specified"
  exit 1
fi

ext=`echo $userlib | awk -F'.' '{print $NF}'`

if test "$ext" = "zip"; then
  unzip -l $userlib | awk '{print $4}' > userlib.files
elif test `echo $userlib | awk -F'.' '{print $NF}'` = gz &&
  test `echo $userlib | awk -F'.' '{print $(NF-1)}'` = "tar" &&
  test `echo $userlib | awk -F'.' '{print NF}'` \> 2; then
  tar -ztvf $userlib | awk '{print $6}' > userlib.files
else
  echo "ERROR: User uploaded lib must be in .gz or .tar.gz format"
  exit 1
fi

var1=`cat userlib.files | cut -c1 | grep "/"`
var2=`cat userlib.files | grep "\.\."`

if test ! -z "$var1" || test ! -z "$var2"; then
  echo "bad"
  echo "bad" >> check.status
else 
  echo "good"
  echo "good" >> check.status 
fi


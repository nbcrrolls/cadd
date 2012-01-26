#!/bin/bash

s=$1                # script name
cmd_file=$2
sb=`basename $s`

echo "#!/bin/bash" > $s
echo "#$ -cwd" >> $s
echo "#$ -S /bin/bash" >> $s
echo "#$ -o $sb.out" >> $s
echo "#$ -e $sb.err" >> $s
echo "" >> $s
cat $cmd_file >> $s



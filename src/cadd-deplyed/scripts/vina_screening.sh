#!/bin/bash
#
# LC and Nadya
#
# script to perform virtual screening suing vina and SGE

#config parameters
#max number of ligand that can be screened per submission 
JOB_LIMIT=4000
#create this file with email inside it to activate the submission based only on ACL
ACL=/home/opaluser/screening/bin/vs.acl
# Libs with no copy right issues
OKLIBS="NCI_DS2 sample"

#fixed variable don't touch them
VINA=/opt/mgltools/bin/vina
LIBRARYBASEDIR=/share/opal/libraries
SCREEN_ROOT=/opt/cadd/bin
#MAX number of job per array with SGE
SGE_JOB_LIMIT=`qconf -sconf | grep max_aj_instances | awk '{print $2}'`

. /etc/profile.d/sge-binaries.sh

echo Inputs arguments: $@

function usage
{
  echo "  ./vina_screening.sh [options] "
  echo 
  echo "      --config file       Used to specify the file with the config option used by vina"
  echo "      --user email        Use to specify the email address to use for sending notificaiton at "
  echo "                          the end of the simulation"
  echo "      --flex file         flexible part of the receptor"
  echo "      --receptor file     receptor pdbqt file"
  echo "      --ligand_db name    used to select the ligand library, can be either NCIDS_SC, or sample"
}


while [ "$1" != "" ]; do
    case $1 in
	--config )              shift 
	                        config=$1
                                ;;
	--user )                shift 
	                        email=$1
                                ;;
        --flex )                shift
                                flex=$1
                                ;;
        --ligand_db )           shift
                                ligand_db=$1
                                ;;
        --receptor )            shift
                                receptor=$1
                                ;;
        --filter )              shift
                                filter=$1
                                ;;
        * )                     pair=`echo $1 $2 | awk -F"--" '{print $2}'`
                                echo $pair | awk '{print $1 " = " $2}'   >> tmp.config
                                shift                                 
    esac
    shift
done


if [ ! "$ligand_db" ]; then
	usage
	echo
    echo "ERROR: You must choose a library to screen against"
	echo ""
	exit -1;
fi

if [ "$flex" ]; then
    if [ ! -f "$flex" ];then
		echo "error flexible chain is not a valid file"
		exit -1
	fi
fi

CURRENTWD=`pwd`

if [ -f "$ACL" ] ; then 
	#we have to enforce the ACL
	ISOK="false"
	for i in `cat $ACL`; do 
		if [ "$i" = "$email" ]; then
			#it's ok
			ISOK="true"
		fi
	done
	if [ "$ISOK" = "false"  ]; then
   	    echo "Your user is not enabled."
   	    echo "Please contact your server admin to get your username enabled."
   	    echo
   	    echo 
   	    exit -1
	fi
fi

receptor=`basename $receptor`


echo Getting list of ligands...
if [ "$filter" ]; then
  #filtering list of ligands
  files=`cat $filter`
  cwd=`pwd`
  rm -f ligands.list
  for i in $files; do
    echo $LIBRARYBASEDIR/$ligand_db/$i >> ligands.list
  done
else
  #getting list of ligands
  s=find_ligands.sh

  echo "#!/bin/bash" >> $s
  echo "#$ -cwd" >> $s
  echo "#$ -S /bin/bash" >> $s
  echo "#$ -o find_ligands.out" >> $s
  echo "#$ -e find_ligands.err" >> $s
  echo "find $LIBRARYBASEDIR/$ligand_db -name \*.pdbqt > ligands.list" >> $s
  chmod +x $s
  qsub -sync y $s
fi


if [ ! -f ligands.list ]; then
  echo "ERROR: Unable to get list of ligands"
  exit 1
fi


NUMLIGANDS=`wc -l ligands.list | awk '{print $1}'`

if [ "$NUMLIGANDS" = 0 ]; then
  echo "ERROR: no ligands found"
  exit 1
fi

echo "There are $NUMLIGANDS ligands."

cp $config $config.org

if test -e tmp.config; then
  cat $config >> tmp.config
  cp tmp.config $config
fi

if [ "$NUMLIGANDS" -gt "$JOB_LIMIT" ]; then
  echo "ERROR: the number of ligands exceeded $JOB_LIMIT, the server cannot support this"
  exit 1
fi



#  -----   Job Submission   -----
#TODO this should be re-written
NUMMACROJOB=`expr $NUMLIGANDS \/ $SGE_JOB_LIMIT`
NUMMACROJOB=`expr $NUMMACROJOB + 1`

for ((i=0; i<$NUMMACROJOB; i++))
do
  begin=`expr $i \* $SGE_JOB_LIMIT`
  begin=`expr $begin + 1`
  end=`expr $begin + $SGE_JOB_LIMIT`
  end=`expr $end - 1`
  awk 'NR>=b && NR<=e' b=$begin e=$end ligands.list > ligands.list.$begin.$end.seeds

  s=vina_array_submit_$begin_$end.sh
  NUMLIGANDS=`wc -l ligands.list.$begin.$end.seeds | awk '{print $1}'`

  echo "#!/bin/bash" > $s
  echo "#$ -clear" >> $s
  echo "#$ -cwd" >> $s
  echo "#$ -S /bin/bash" >> $s
  echo "#$ -t 1-$NUMLIGANDS" >> $s
  echo "#$ -o vina_array_submit.$begin.$end.out" >> $s
  echo "#$ -e vina_array_submit.$begin.$end.err" >> $s
  echo "" >> $s
  echo "SEEDFILE=ligands.list.$begin.$end.seeds" >> $s
  echo "ls \$SEEDFILE > /dev/null" >> $s
  echo "SPDBQT=\$(cat \$SEEDFILE | head -n \$SGE_TASK_ID | tail -n 1)" >> $s
  echo "SEED=\$(basename \$SPDBQT .pdbqt)" >> $s
  echo "mkdir \$SEED" >> $s
  echo "cp \$SPDBQT \$SEED" >> $s
  echo "cp $receptor \$SEED" >> $s
  echo "cp $config \$SEED" >> $s
  echo "if test ! -z \"$flex\"; then" >> $s
  echo "  cp $flex \$SEED" >> $s
  echo "  FLAGS=\"--flex $flex\"" >> $s
  echo "fi" >> $s
  echo "cd \$SEED" >> $s
#  echo "cp ../*.pdbqt ." >> $s
  echo "touch $CURRENTWD" >> $s
  echo "$VINA --config $config --receptor $receptor --ligand \$SEED.pdbqt --cpu 1 $FLAGS >& sge_array_\$SEED.log" >> $s
  
  chmod +x $s
  
  echo "Submitting Vina array job ($begin-$end) to the SGE scheduler"
  
  qsub -sync y $s

  echo "Vina array job ($begin-$end) finished."
done

$SCREEN_ROOT/vina_screening/extractResults.py ./

tar -czf results.tar.gz .

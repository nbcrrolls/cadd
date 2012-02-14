#!/bin/bash

VINA=/opt/mgltools/bin/vina
LIBRARYBASEDIR=/share/opal/libraries
SCREEN_ROOT=/opt/cadd/bin
#LOGDIR="/opt/cadd/logs"
SGE_JOB_LIMIT=75000
#JOB_LIMIT=2500
JOB_LIMIT=25000
ACL=/home/opaluser/screening/bin/vs.acl
webapps=/share/opal/opal-jobs
show=200

# Libs with no copy right issues
OKLIBS="NCI_DS2 sample"

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
  echo "      --userlib file      not supported at the moment "
  echo "      --urllib name       not supported at the moment"
}

function extract_results(){
    #this function sumarizes the results 
    #of a virtual screening simulation 
    for i in */*.log;
    do
        grep "^   1 " $i >> temp_energies
    done
    ls -d */ > temp_dirs
    paste temp_dirs temp_energies > temp_pasted
    sort -k 3 -g temp_pasted | head -n 500 > screen_result_summary.log
    
    rm temp_dirs
    rm temp_pasted
    rm temp_energies
    
}

other_args=""

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
        --userlib )             shift
                                userlib=$1
                                ;;
        --urllib )              shift
                                urllib=$1
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


if [ $userlib  ]; then
	usage
	echo
	echo "      --userlib option not supported"
	exit -1;
fi

if [ $urllib ]; then
        usage
        echo
        echo "      --urllib option not supported"
        exit -1;
fi



hide="false"

if test ! -z "$ligand_db"; then
  if test -e $LIBRARYBASEDIR/$ligand_db; then
    n=`find $LIBRARYBASEDIR/$ligand_db -name \*.pdbqt | wc -l | awk '{print $1}'`
    if test $n -gt $show; then
      hide="true"
    fi
  fi
fi

cdir=`pwd`
mdir=`dirname $cdir`
cbd=`basename $cdir`

if test -z "$userlib"; then
  WORKINGDIR=`date '+%s'`
  WORKINGDIR="app""$WORKINGDIR$RANDOM"
  WORKINGDIR=$mdir/$WORKINGDIR
  mkdir $WORKINGDIR
  wbd=`basename $WORKINGDIR`
  #echo "$cbd - $wbd" >> $LOGDIR/results.log
else
  WORKINGDIR=$cdir
fi

if test "$hide" = "true"; then

  echo "WARNING: Only the top-300 results will be displayed due to copyright issues"
  echo "         Contact admin@nbcr.net if you need access"

  for f in `ls`; do
    if test $f != "stdout.txt" && test $f != "stderr.txt"; then
      cp -r $f $WORKINGDIR
    fi
  done

  cd $WORKINGDIR
fi

if test -z "$email"; then
  access="false"
else
  var=`grep ^$email$ $ACL`;
  if test -z "$var"; then
    access="false";
  else
    access="true";
  fi
fi

if test ! -z "$email"; then
  if test "$hide" = "true"; then
    if test "$access" = "true"; then
      echo -e "The full results to your virtual screening job $cbd can be found at http://kryptonite.nbcr.net/$wbd\n" | mail -s "Vina Virtual Screening Full Results" $email      
    else
      echo -e "Sorry, you do not currently have access to the ZINC library results. Please contact admin@nbcr.net\n" | mail -s "Vina Virtual Screening Full Results Denied" $email
    fi
  else
    echo -e "The full results to your virtual screening job $cbd can be found at http://kryptonite.nbcr.net/$cbd" | mail -s "Vina Virtual Screening Full Results" $email      
  fi
fi

receptor=`basename $receptor`

if test -z "$ligand_db" && test -z "$userlib" && test -z "$urllib"; then
  echo "ERROR: You must choose to use a library on the server, upload your own library or enter a ligand library URL"
  exit 1
fi

if test ! -z "$urllib"; then
  if test -d "$LIBRARYBASEDIR/$urllib"; then
    ligand_db=$urllib
    urllib=""
  fi

  gz_ext=`echo $urllib | grep ".tar.gz"`
  zip_ext=`echo $urllib | grep ".zip"`

  if test ! -z "$gz_ext" || test ! -z "$zip_ext"; then
    userlib=$urllib
    urllib=""
  fi
fi

if test ! -z "$urllib"; then
  var=`echo $urllib | grep "kryptonite.nbcr.net"`

  if test -z "var"; then
    echo "ERROR: We currently only support URL libs from our server kryptonite"
    exit 0
  fi

  appname=`echo $urllib | awk -F"kryptonite.nbcr.net/" '{print $2}' | awk -F'/' '{print $1}'`
#TODO
  libinfo=`grep $appname $SCREEN_ROOT/user_ligand_db_info/all_uploads.txt`

  if test -z "$libinfo"; then
    LIBRARYBASEDIR=$webapps/$appname
    ligand_db="filtered"
  else
    LIBRARYBASEDIR=`echo $libinfo | awk '{print $2}'`
    ligand_db=`echo $libinfo | awk '{print $3}'`
  fi

  echo LIBRARYBASEDIR $LIBRARYBASEDIR
  echo ligand_db $ligand_db

  if test -z "$LIBRARYBASEDIR" || test -z "$ligand_db"; then
    echo "ERROR: LIBRARYBASEDIR or ligand_db empty for urllib"
    exit 1    
  fi
fi

if test ! -z "$userlib"; then
  ext=`echo $userlib | awk -F'.' '{print $NF}'`

  if test -z "$ext"; then
    echo "ERROR: Unable to determine file extension for $userlib"
    exit 1
  fi
  
  libsize=`du $userlib | awk '{print $1}'`
   
  if test "$libsize" -gt 1000; then
    echo "$SCREEN_ROOT/autodock-vina/compressfiles_check.sh $userlib" > tmp.file
    $SCREEN_ROOT/autodock-vina/make_sge_script.sh cf_check.sh tmp.file
    qsub -sync y cf_check.sh
  else
    $SCREEN_ROOT/autodock-vina/compressfiles_check.sh $userlib
  fi

  status=`cat check.status`
    
  if test "$status" != "good"; then
    echo "ERROR: User ligand library $userlib contains invalid paths."
    echo "File paths cannot begin with / or contain .."
    exit 1
  fi

  if test "$ext" = "zip"; then
    var=`unzip $userlib`
    LIBRARYBASEDIR=`pwd`
    ligand_db=`echo $var | awk -F'/' '{print $1}' | awk '{print $NF}'`
  elif test `echo $userlib | awk -F'.' '{print $NF}'` = gz &&
     test `echo $userlib | awk -F'.' '{print $(NF-1)}'` = "tar" &&
     test `echo $userlib | awk -F'.' '{print NF}'` \> 2; then

    if test "$libsize" -gt 1000; then
      echo "tar -zxvf $userlib >> untar.result" > tmp.file
      $SCREEN_ROOT/autodock-vina/make_sge_script.sh untar.sh tmp.file
      qsub -sync y untar.sh
      uz=`head -n 1 untar.result`
    else
      uz=`tar -zxvf $userlib`
    fi

    rm -f $userlib
    echo "UZ=$uz"
    echo "UZ1=$uz1"
    uz1=`echo $uz | cut -f1 -d" "`
    LIBRARYBASEDIR=`pwd`
    ligand_db=`dirname $uz1`
  else
    echo "ERROR: Your loaded library file must be in tar.gz or zip format"
    exit -1
  fi

  echo BASEDIR $LIBRARYBASEDIR
  echo NAME $ligand_db

  var1=`echo $LIBRARYBASEDIR | grep "\.\."`
  var2=`echo $ligand_db | grep "\.\."`

  if test ! -z "$var1" || test ! -z "$var2"; then
    echo "ERROR: There cannot be .. in LIBRARY PATH"
    exit 1
  fi
fi

if test -z "$ligand_db"; then
  echo "ERROR: No ligand DB provided"
  exit 1
fi

if test ! -z "$filter"; then
  files=`cat $filter`
  cwd=`pwd`

  rm -f ligands.list

  for i in $files; do
    echo $LIBRARYBASEDIR/$ligand_db/$i >> ligands.list
  done
else
  s=find_ligands.sh

  echo "#!/bin/bash" >> $s
  #echo "#$ -clear" >> $s
  echo "#$ -cwd" >> $s
  echo "#$ -S /bin/bash" >> $s
  echo "#$ -o find_ligands.out" >> $s
  echo "#$ -e find_ligands.err" >> $s
  echo "find $LIBRARYBASEDIR/$ligand_db -name \*.pdbqt > ligands.list" >> $s

  chmod +x $s

  echo "Starting to get a list of ligands"
  qsub -sync y $s
fi

if test ! -e ligands.list; then
  echo "ERROR: Unable to get list of ligands"
  exit 1
fi


NUMLIGANDS=`wc -l ligands.list | awk '{print $1}'`

if test "$NUMLIGANDS" = 0; then
  echo "ERROR: no ligands found"
  exit 1
fi

echo "There are $NUMLIGANDS ligands."

cp $config $config.org

var=`grep ^receptor $config`

if test -z "$var"; then
  echo "" >> $config
  echo "receptor = " >> $config
fi

var=`grep ^ligand $config`

if test -z "$var"; then
  echo "" >> $config
  echo "ligand = " >> $config
fi

if test -e tmp.config; then
  cat $config >> tmp.config
  cp tmp.config $config
fi

if test -z $ligand_db; then
  echo ERROR: No ligand lib specified
  exit
fi

if test -z "$filter"; then
  numjobs=$NUMLIGANDS
else
  numjobs=`wc -l filter | awk '{print $1}'`
fi

if test "$numjobs" -gt "$JOB_LIMIT"; then
  echo "ERROR: NUMLIGANDS exceeded 2500, the server cannot support this"
  exit 1
fi


it=`expr $NUMLIGANDS \/ $SGE_JOB_LIMIT`
it=`expr $it + 1`

for ((i=0; i<$it; i++))
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
  echo "fi" >> $s
  echo "sed -i \"s%ligand.*$%ligand = \$SEED.pdbqt%\" \$SEED/$config" >> $s
  echo "sed -i \"s%receptor.*$%receptor = $receptor%\" \$SEED/$config" >> $s
  echo "cd \$SEED" >> $s
  echo "cp ../*.pdbqt ." >> $s
  echo "touch $WORKINGDIR" >> $s
  echo "touch $cdir" >> $s
  echo "$VINA --config $config >& sge_array_\$SEED.log" >> $s
  
  chmod +x $s
  
  echo "Submitting Vina array job ($begin-$end) to the SGE scheduler"
  
  if test "$access" = "false"; then
    echo "It appears that you do get access to the full results, please contact admin@nbcr.net to see if you can get permission"
    echo "Only top results will be displayed"
  fi

  qsub -sync y $s

  echo "Vina array job ($begin-$end) finished."
done



extract_results

#TODO fix this
cp /home/opaluser/screening/README $cdir/README_CITE

cd $cdir

if test "$hide" = "true"; then
  tops=`cat $WORKINGDIR/screen_result_summary.log | grep -v "Parse error" | awk '{print $1}' | head -n $show`
  for i in $tops; do
    cp -r $WORKINGDIR/$i .
  done

  cat $WORKINGDIR/screen_result_summary.log | grep -v "Parse error" | head -n $show > screen_result_summary.log.partial
fi



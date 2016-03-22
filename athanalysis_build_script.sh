#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

###########################
# Written by dpluth@cern.ch
#            will@cern.ch
###########################

ARCH=x86_64
ARCHBIT=64
GCCV=gcc49
MACHINE=slc6
if [ $# -eq 0 ]
then
    echo "No arguments supplied"
    echo "Specify what flavor of release you are building (Base, SUSY)"
    exit
else 
    ATHVERSION=$1
fi


if [[ $ATHVERSION != "Base" ]] && [[ $ATHVERSION != "SUSY" ]] 
then
    echo "Specify what flavor of release you are building (Base, SUSY)"
    exit
fi

echo "$ATHVERSION"


NIGHTLY_NAME=NULL
if [[ $ATHVERSION == "SUSY" ]] 
then
    NIGHTLY_NAME="2.3.X"
else
    echo "enter the nightly name (ex. 1.X.0): "
    until ( [[ $NIGHTLY_NAME == "2.X.0" ]] || [[ $NIGHTLY_NAME == "2.4.X" ]]|| [[ $NIGHTLY_NAME == "2.3.X" ]] ||  [[ $NIGHTLY_NAME == "1.X.0" ]] )
    do
        read -r NIGHTLY_NAME
        echo ""
        ( [[ $NIGHTLY_NAME == "2.X.0" ]] || [[ $NIGHTLY_NAME == "2.4.X" ]]|| [[ $NIGHTLY_NAME == "2.3.X" ]] ||  [[ $NIGHTLY_NAME == "1.X.0" ]] )&& echo "Nightly name is $NIGHTLY_NAME" || echo "Incorrect value, try again"
    done
fi


REL_NUMBER=NULL
echo "enter the release number (ex. 1.5.11): "
until ( [[ $REL_NUMBER =~ ^[1-9].[0-9].(([0-9][0-9]|[0-9])([a-z]$|$)) ]])
do
    read -r REL_NUMBER
    echo ""
    ( [[ $REL_NUMBER =~ ^[1-9].[0-9].(([0-9][0-9]|[0-9])([a-z]$|$)) ]]) || echo "Incorrect value"
done
echo "Release number is $REL_NUMBER"



REL_NAME=NULL
echo "enter the nightly to build off of (ex. rel_1): "
until [[ $REL_NAME =~ ^rel_[0-6]$ ]] 
do
    read -r REL_NAME
    echo ""
    [[ $REL_NAME =~ ^rel_[0-6]$ ]] && echo "nightly is $REL_NAME" || echo "Incorrect value"
done

SKIP_VAL=0
if [ $# -eq 2 ]
then 
    if [[ "$2" == "SKIP" ]]
    then 
        echo "What section would you like to skip to?"
        echo -e "\t1) Copy"
        echo -e "\t2) Building the kit"
        echo -e "\t3) Simply check the files to send to grid install"
        until  [[ $SKIP_VAL =~ ^[1-3]$ ]]
        do
            read -r SKIP_VAL
            echo ""
            [[ $SKIP_VAL =~ ^[1-3]$ ]] || echo "Incorrect value"
        done
    fi
fi

if [[ $SKIP_VAL -lt 1 ]]
then 
    echo "Checking tag diffs, please wait"


    /afs/cern.ch/user/a/alibrari/scripts/tags_diffs_tc_afs.sh -p AthAnalysis"$ATHVERSION" --tc "$REL_NUMBER" --night "$NIGHTLY_NAME" --afs "$REL_NAME"

    echo "Are there any tag conflicts? [y/n]"
    read -r KILL_PROG
    echo ""
    if [ "$KILL_PROG" = "y" ] # or Y
    then
        echo "Go to AMI and fix problems, email the appropriate people if necessary"
        exit
    fi

    echo "Now go to ami and tag the release and terminate. When you are ready, press y [y/n]"
    read -r CONTIN
    echo ""
    if [[ "$CONTIN" = "n" || "$CONTIN" = "N" ]] # or Y
    then
        exit
    fi

    echo -e "\n"


    cd /afs/cern.ch/atlas/software/builds/logs/AthAnalysis"$ATHVERSION"
    mkdir "$REL_NUMBER"
    cd "$REL_NUMBER"
    cp ../2.3.41/build_2.3.41.cfg  build_"$REL_NUMBER.cfg"
    sed -i s/2.3.41/"$REL_NUMBER"/g build_"$REL_NUMBER.cfg"

fi
echo "Have you been told to deploy a new Gaudi Version (ASG Convenor will inform you)? [y/n]"
GAUDIY=NULL
read -r GAUDIY
if [[ "$GAUDIY" = "y" || "$GAUDIY" = "Y" ]] # or Y
then
    GAUDIV=0
    echo "enter the gaudi version (e.g. GAUDI-v26r2p1-lcg81): "
    until [[ $GAUDIV =~ ^GAUDI-v[0-9][0-9] ]] 
    do
        read -r GAUDIV 
        echo ""
        [[ $GAUDIV =~ ^GAUDI-v[0-9][0-9] ]] && echo "gaudi version is $GAUDIV" || echo "Incorrect value"

    done
    echo "$GAUDIV"|cat - build_"$REL_NUMBER".cfg > /tmp/out && mv /tmp/out build_"$REL_NUMBER".cfg
fi


if [[ $SKIP_VAL -lt 2 ]]
then 
    echo "Copying release, please wait...this will take nearly an hour. If it lasts much longer than an hour then check the logs in a seperate shell to make sure it's working: "
    echo -e "\t \e[34m/afs/cern.ch/atlas/software/builds/logs/AthAnalysis$ATHVERSION/$REL_NUMBER/copy_$NIGHTLY_NAME"_"$REL_NAME.log"
    echo -e "\e[39m"

    sleep 10
    echo "Calling: /afs/cern.ch/user/a/alibrari/scripts/copy_nightlies.sh -f build_"$REL_NUMBER".cfg -n $NIGHTLY_NAME -n_r $REL_NAME --vol"
    echo "From: ""$PWD"

    /afs/cern.ch/user/a/alibrari/scripts/copy_nightlies.sh -f build_"$REL_NUMBER".cfg -n "$NIGHTLY_NAME" -n_r "$REL_NAME" --vol

    echo -e "\e[39m"
    echo "Now we should test the release, to make sure things are functioning correctly:"
    echo "Execute the following in a seperate shell (the 'builds' option ensures asetup looks for the release in the afs builds area, because it's not available on cvmfs yet):"

    echo -e "\t \e[34masetup AthAnalysis$ATHVERSION,$REL_NUMBER,builds,here"
    echo -e "\t"' \e[34mcheckMetaSG.py $ROOTCORE_TEST_FILE'

    echo -e "\e[39m"

    sleep 10
fi

echo "Is gcc version = "$GCCV"? [y/n]"
read -r GCCY
if [[ "$GCCY" = "n" || "$GCCY" = "N" ]] # or Y
then
    GCCV=0
    echo "enter the gcc version(ex. gcc49): "
    until [[ $GCCV =~ ^gcc[0-9][0-9]$ ]] 
    do
        read -r GCCV 
        echo ""
        [[ $GCCV =~ ^gcc[0-9][0-9]$ ]] && echo "gcc version is $GCCV" || echo "Incorrect value"
    done
fi

echo -e "\e[39m"



if [[ $SKIP_VAL -lt 3 ]]
then 
    echo "We will now make the kit"
    echo "This will take some time, you will see the log file updating, when it stops, press Control-C. Don't be fooled, it will pause for a while in the middle. It is finished once you see the word 'Finish' in the latest few lines of output, along with the time the script finished executing."
    sleep 10

    echo ""

    cp ../2.3.41/prod_$MACHINE"_"opt.cfg ./
    sed -i s/2.3.41/"$REL_NUMBER"/g prod_$MACHINE"_"opt.cfg
    sed -i s/slc6_0/slc6_1/g prod_$MACHINE"_"opt.cfg

    #need to have -R option (recursive kit build) if building a gaudi release too
    extraopt=""
    if [[ "$GAUDIY" = "y" || "$GAUDIY" = "Y" ]] # or Y
    then
        extraopt=" -R "
    fi
    echo "~alibrari/Kit/PackDist/latest/scripts/proj-run.sh -c prod_$MACHINE"_"opt.cfg -r $REL_NUMBER -P AthAnalysis$ATHVERSION -t $ARCHBIT,$GCCV,$MACHINE -j /afs/cern.ch/atlas/project/repos/offline/$MACHINE $extraopt"

    ~alibrari/Kit/PackDist/latest/scripts/proj-run.sh -c prod_"$MACHINE""_"opt.cfg -r "$REL_NUMBER" -P AthAnalysis"$ATHVERSION" -t "$ARCHBIT","$GCCV","$MACHINE" -j /afs/cern.ch/atlas/project/repos/offline/"$MACHINE" "$extraopt"

    watch tail proj-run-"$ARCH"-"$MACHINE"-"$GCCV"-opt.log

    echo "Next step is to build the pacball, it will output the pacball file name and dataset name."
    echo "Ready to continue? [y/n]"
    read -r CONTIN2
    echo ""
    if [[ "$CONTIN2" = "n" || "$CONTIN2" = "N" ]] # or Y
    then
        echo "If there were problems with the build contact an expert"
        exit
    fi
    echo "Running: createrepo --update /afs/cern.ch/atlas/project/repos/offline/$MACHINE/yum"
    createrepo --update /afs/cern.ch/atlas/project/repos/offline/$MACHINE/yum
    echo "Running: cd /afs/cern.ch/atlas/software/kits/projects ; lndir $MACHINE\"_\"1 ; ~asgbase/scripts/setupVOMSDQ2.sh ; ~alibrari/scripts/create_and_copy_pacball.sh -r $REL_NUMBER -p AthAnalysis$ATHVERSION -C $ARCH-$MACHINE-$GCCV-opt"
    cd /afs/cern.ch/atlas/software/kits/projects
    lndir $MACHINE"_"1
    ~asgbase/scripts/setupVOMSDQ2.sh
    ~alibrari/scripts/create_and_copy_pacball.sh -r "$REL_NUMBER" -p AthAnalysis"$ATHVERSION" -C "$ARCH"-"$MACHINE"-"$GCCV"-opt
fi

echo "Email the pacball file name and dataset name to atlas-grid-install@cern.ch, these are likely the right ones:"
NEWRELNUMBER=${REL_NUMBER//\./_}


echo "/afs/cern.ch/atlas/software/builds/logs/AthAnalysis"$ATHVERSION"/"$REL_NUMBER"/""AthAnalysis"$ATHVERSION"_"$NEWRELNUMBER"_"$ARCH"_"$MACHINE"_"$GCCV"_opt_pacball.log"
DATASET=`cat "/afs/cern.ch/atlas/software/builds/logs/AthAnalysis"$ATHVERSION"/"$REL_NUMBER"/AthAnalysis"$ATHVERSION"_"$NEWRELNUMBER"_"$ARCH"_"$MACHINE"_"$GCCV"_opt_pacball.log" | grep registered | grep Container | awk -F' ' '{print $2}'`
INSTALL_SCRIPT=`cat "/afs/cern.ch/atlas/software/builds/logs/AthAnalysis"$ATHVERSION"/"$REL_NUMBER"/AthAnalysis"$ATHVERSION"_"$NEWRELNUMBER"_"$ARCH"_"$MACHINE"_"$GCCV"_opt_pacball.log" | grep "Transfer of file" | awk -F' ' '{print $5}'`
echo "dataset defined"

# echo -e "\t \e[34mAthAnalysis""$ATHVERSION"_"$NEWRELNUMBER"_"$ARCH"_"$MACHINE"_"$GCCV"_"opt"
echo -e "\t \e[34m$DATASET"
echo -e "\t \e[34m$INSTALL_SCRIPT"

echo -e "\e[39m"

echo "Also email undrus@bnl.gov and yesw@bnl.gov to request AthAnalysis $REL_NUMBER be indexed in lxr"

echo "" 

echo "If you have seen any errors in this process its likely that something failed. Review where the problem showed up. If it's not clear, email an expert or the writer of this script"

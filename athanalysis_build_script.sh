#!/bin/bash
###########################
# Written by dpluth@cern.ch
#            will@cern.ch
###########################

arch=x86_64
archbit=64
gccv=gcc49
machine=slc6
athversion=$1

if [[ $athversion != "Base" ]] && [[ $athversion != "SUSY" ]] 
then
echo "Specify what flavor of release you are building (Base, SUSY)"
exit
fi

echo $athversion


if [[ $athversion == "SUSY" ]] 
then
nightly_name="2.3.X"
else
echo "enter the nightly name (ex. 1.X.0): "
until ( [[ $nightly_name == "2.X.0" ]] || [[ $nightly_name == "2.4.X" ]]|| [[ $nightly_name == "2.3.X" ]] ||  [[ $nightly_name == "1.X.0" ]] )
do
    read nightly_name
    echo ""
    ( [[ $nightly_name == "2.X.0" ]] || [[ $nightly_name == "2.4.X" ]]|| [[ $nightly_name == "2.3.X" ]] ||  [[ $nightly_name == "1.X.0" ]] )&& echo "Nightly name is $nightly_name" || echo "Incorrect value, try again"
done
fi


echo "enter the release number (ex. 1.5.11): "
until ( [[ $rel_number =~ ^[1-9].[0-9].(([0-9][0-9]|[0-9])([a-z]$|$)) ]])
do
    read rel_number
    echo ""
    ( [[ $rel_number =~ ^[1-9].[0-9].(([0-9][0-9]|[0-9])([a-z]$|$)) ]]) || echo "Incorrect value"
done
echo "Release number is $rel_number"



echo "enter the nightly to build off of (ex. rel_1): "
until [[ $rel_name =~ ^rel_[0-6]$ ]] 
do
    read rel_name
    echo ""
    [[ $rel_name =~ ^rel_[0-6]$ ]] && echo "nightly is $rel_name" || echo "Incorrect value"
done

echo "Checking tag diffs, please wait"


/afs/cern.ch/user/a/alibrari/scripts/tags_diffs_tc_afs.sh -p AthAnalysis$athversion --tc $rel_number --night $nightly_name --afs $rel_name

echo "Are there any tag conflicts? [y/n]"
read kill_prog
echo ""
if [ "$kill_prog" = "y" ] # or Y
then
    echo "Go to AMI and fix problems, email the appropriate people if necessary"
    exit
fi

echo "Now go to ami and tag the release and terminate. When you are ready, press y [y/n]"
read contin
echo ""
if [[ "$contin" = "n" || "$contin" = "N" ]] # or Y
then
    exit
fi

echo -e "\n"


cd /afs/cern.ch/atlas/software/builds/logs/AthAnalysis$athversion
mkdir $rel_number
cd $rel_number
cp ../2.3.41/build_2.3.41.cfg  build_$rel_number.cfg
sed -i s/2.3.41/$rel_number/g build_$rel_number.cfg

echo "Have you been told to deploy a new Gaudi Version (ASG Convenor will inform you)? [y/n]"
read gaudiy
if [[ "$gaudiy" = "y" || "$gaudiy" = "Y" ]] # or Y
then
    gaudiv=0
    echo "enter the gaudi version (e.g. GAUDI-v26r2p1-lcg81): "
    until [[ $gaudiv =~ ^GAUDI-v[0-9][0-9] ]] 
    do
        read gaudiv 
        echo ""
        [[ $gaudiv =~ ^GAUDI-v[0-9][0-9] ]] && echo "gaudi version is $gaudiv" || echo "Incorrect value"

    done
    echo "$gaudiv"|cat - build_"$rel_number".cfg > /tmp/out && mv /tmp/out build_"$rel_number".cfg
fi


echo "Copying release, please wait...this will take nearly an hour. If it lasts much longer than an hour then check the logs in a seperate shell to make sure it's working: "
echo -e "\t \e[34m/afs/cern.ch/atlas/software/builds/logs/AthAnalysis$athversion/$rel_number/copy_$nightly_name"_"$rel_name.log"
echo -e "\e[39m"

sleep 10
echo "Calling: /afs/cern.ch/user/a/alibrari/scripts/copy_nightlies.sh -f build_"$rel_number".cfg -n $nightly_name -n_r $rel_name --vol"
echo "From: "$PWD

/afs/cern.ch/user/a/alibrari/scripts/copy_nightlies.sh -f build_"$rel_number".cfg -n $nightly_name -n_r $rel_name --vol

echo -e "\e[39m"
echo "Now we should test the release, to make sure things are functioning correctly:"
echo "Execute the following in a seperate shell (the 'builds' option ensures asetup looks for the release in the afs builds area, because it's not available on cvmfs yet):"

echo -e "\t \e[34masetup AthAnalysis$athversion,$rel_number,builds,here"
echo -e "\t"' \e[34mcheckMetaSG.py $ROOTCORE_TEST_FILE'

echo -e "\e[39m"

sleep 10

echo "Is gcc version = "$gccv"? [y/n]"
read gccy
if [[ "$gccy" = "n" || "$gccy" = "N" ]] # or Y
then
    gccv=0
    echo "enter the gcc version(ex. gcc49): "
    until [[ $gccv =~ ^gcc[0-9][0-9]$ ]] 
    do
        read gccv 
        echo ""
        [[ $gccv =~ ^gcc[0-9][0-9]$ ]] && echo "gcc version is $gccv" || echo "Incorrect value"
    done
fi

echo -e "\e[39m"



echo "We will now make the kit"
echo "This will take some time, you will see the log file updating, when it stops, press Control-C. Don't be fooled, it will pause for a while in the middle. It is finished once you see the word 'Finish' in the latest few lines of output, along with the time the script finished executing."
sleep 10

echo ""

cp ../2.3.41/prod_$machine"_"opt.cfg ./
sed -i s/2.3.41/$rel_number/g prod_$machine"_"opt.cfg
sed -i s/slc6_0/slc6_1/g prod_$machine"_"opt.cfg

#need to have -R option (recursive kit build) if building a gaudi release too
extraopt=""
if [[ "$gaudiy" = "y" || "$gaudiy" = "Y" ]] # or Y
then
    extraopt=" -R "
fi
echo "~alibrari/Kit/PackDist/latest/scripts/proj-run.sh -c prod_$machine"_"opt.cfg -r $rel_number -P AthAnalysis$athversion -t $archbit,$gccv,$machine -j /afs/cern.ch/atlas/project/repos/offline/$machine $extraopt"

~alibrari/Kit/PackDist/latest/scripts/proj-run.sh -c prod_$machine"_"opt.cfg -r $rel_number -P AthAnalysis$athversion -t $archbit,$gccv,$machine -j /afs/cern.ch/atlas/project/repos/offline/$machine $extraopt

watch tail proj-run-"$arch"-"$machine"-"$gccv"-opt.log

echo "Next step is to build the pacball, it will output the pacball file name and dataset name."
echo "Ready to continue? [y/n]"
read contin2
echo ""
if [[ "$contin2" = "n" || "$contin2" = "N" ]] # or Y
then
    echo "If there were problems with the build contact an expert"
    exit
fi
echo "Running: createrepo --update /afs/cern.ch/atlas/project/repos/offline/$machine/yum"
createrepo --update /afs/cern.ch/atlas/project/repos/offline/$machine/yum
echo "Running: cd /afs/cern.ch/atlas/software/kits/projects ; lndir $machine\"_\"1 ; ~asgbase/scripts/setupVOMSDQ2.sh ; ~alibrari/scripts/create_and_copy_pacball.sh -r $rel_number -p AthAnalysis$athversion -C $arch-$machine-$gccv-opt"
cd /afs/cern.ch/atlas/software/kits/projects
lndir $machine"_"1
~asgbase/scripts/setupVOMSDQ2.sh
~alibrari/scripts/create_and_copy_pacball.sh -r $rel_number -p AthAnalysis$athversion -C $arch-$machine-$gccv-opt


echo "Email the pacball file name and dataset name to atlas-grid-install@cern.ch, these are likely the right ones:"
newrelnumber=`echo $rel_number | sed 's/\./_/g'`

dataset=`cat /afs/cern.ch/atlas/software/builds/logs/AthAnalysis"$athversion"/"$rel_number"/AthAnalysis"$athversion"_"$newrelnumber"_"$arch"_"$machine"_"$gccv"_opt_pacball.log | grep registered | grep Container | awk -F' ' '{print $2}'`

echo -e "\t \e[34mAthAnalysis"$athversion"_$newrelnumber"_"$arch"_"$machine"_"$gccv"_"opt"
echo -e "\t \e[34m$dataset"

echo -e "\e[39m"

echo "Also email undrus@bnl.gov and yesw@bnl.gov to request AthAnalysis $rel_number be indexed in lxr"

echo "" 

echo "If you have seen any errors in this process its likely that something failed. Review where the problem showed up. If it's not clear, email an expert or the writer of this script"

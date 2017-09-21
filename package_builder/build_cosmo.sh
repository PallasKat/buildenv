#!/usr/bin/env bash

exitError()
{
	echo "ERROR $1: $3" 1>&2
	echo "ERROR     LOCATION=$0" 1>&2
	echo "ERROR     LINE=$2" 1>&2
	exit "$1"
}

tryExit()
{
	status=$1
	action=$2
	if [ "${status}" -ne 0 ]; then
		echo "ERROR in ${action} with ${status}" >&2
		exit "${status}"
  fi
}

showUsage()
{
	echo "usage: $(basename "$0") [-h] [-4] [-t target] [-c compiler] [-s slave] [-f kflat] [-l klevel] [-z]"
	echo ""
	echo "optional arguments:"
	echo "-4        Single precision (default: OFF)"
	echo "-t        Target (e.g. cpu or gpu)"
  echo "-c        Compiler (e.g. gnu, cray or pgi)"
	echo "-s        Slave (the machine)"
	echo "-f        STELLA K-Flat"
	echo "-l        STELLA K-Level"
	echo "-z        Clean builds"
	echo "-g        Do GNU build: Stella and the CPP Dycore"
}

# set defaults and process command line options
parseOptions()
{	
	singleprec=OFF
	compiler=""
	target=""
	slave=""
	kflat=""
	klevel=""
	verbosity=OFF
	cleanup=OFF
	doGNU=OFF

	while getopts "h:4ctsfl:v:z:g" opt; do
		case $opt in
		h) 
				showUsage
			  exit 0 
		  	;;
		4) 
		    singleprec=ON 
		    ;;
		c) 
		    compiler=$OPTARG 
		    ;;
		t) 
		    target=$OPTARG
		    ;;
		s)
				slave=$OPTARG
				;;
		f)
				kflat=$OPTARG
				;;
		l)
				klevel=$OPTARG
				;;
		v) 
		    verbosity=ON
		    ;;
		z) 
		    cleanup=ON
		    ;;
		g) 
		    doGNU=ON
		    ;;
		\?) 
		    showUsage
		    exitError 601 ${LINENO} "invalid command line option (-${OPTARG})"
		    ;;
		:) 
		    showUsage
		    exitError 602 ${LINENO} "command line option (-${OPTARG}) requires argument"
		    ;;
		esac
	done
}

# make sure the working variable are set
checkOptions()
{	
	test -n "${compiler}" || exitError 603 ${LINENO} "Option <compiler> is not set"
	test -n "${target}" || exitError 604 ${LINENO} "Option <target> is not set"
	test -n "${slave}" || exitError 605 ${LINENO} "Option <slave> is not set"
	test -n "${kflat}" || exitError 606 ${LINENO} "Option <flat> is not set"
	test -n "${klevel}" || exitError 607 ${LINENO} "Option <klevel> is not set"
}


printConfig()
{
	echo "==============================================================="
	echo "BUILD CONFIGURATION"
	echo "==============================================================="
	echo "SINGLE PRECISION    ${singleprec}"
	echo "COMPILER            ${compiler}"
	echo "TARGET              ${target}"
	echo "SLAVE               ${slave}"
	echo "K-FLAT              ${kflat}"
	echo "K-LEVEL             ${klevel}"
	echo "VERBOSE             ${verbosity}"
	echo "CLEAN               ${cleanup}"
	echo "DO GNU COMPILATION  ${doGNU}"
	echo "==============================================================="
}

# clone the repositories
cloneTheRepos()
{	
	git clone git@github.com:MeteoSwiss-APN/stella.git --branch crclim
	git clone git@github.com:C2SM-RCM/cosmo-pompa.git --branch crclim
}

setupBuilds()
{
	# single precision flag
	moreFlag=""
	if [ ${singleprec} == "ON" ] ; then
		moreFlag="${moreFlag} -4"
	fi

	if [ ${verbosity} == "ON" ] ; then
		moreFlag="${moreFlag} -v"
	fi

	if [ ${cleanup} == "ON" ] ; then
		moreFlag="${moreFlag} -z"
	fi

	# compiler (for Stella and the Dycore)
  gnuCompiler="gnu"
	# path and directory structures
	stellapath="/project/c14/install/${slave}/crclim/stella_kflat8_klevel40/${compiler}"
	dycorepath="/project/c14/install/${slave}/crclim/dycore_cordex/${target}/${compiler}"
	cosmopath="/project/c14/install/${slave}/crclim/cosmo_cordex/${target}/${compiler}"

	# clean previous install path
	\rm -rf "${stellapath:?}/"*
	\rm -rf "${dycorepath:?}/"*
	\rm -rf "${cosmopath:?}/"*
}

# compile and install stella and the dycore
doGnuOnlyCompilation()
{
	doStella
	doDycore
}

# compile and install stella
doStella()
{
	cd stella || exitError 608 ${LINENO} "Unable to change directory into stella"
	test/jenkins/build.sh "${moreFlag}" -c "${gnuCompiler}" -i "${stellapath}" -f "${kflat}" -k "${klevel}" -z
	retCode=$?
	tryExit $retCode "STELLA BUILD"
	cd .. || exitError 609 ${LINENO} "Unable to go back"
}

# compile and install the dycore
doDycore()
{
	cd cosmo-pompa/dycore || exitError 610 ${LINENO} "Unable to change directory into cosmo-pompa/dycore"	
	test/jenkins/build.sh "${moreFlag}" -c "${gnuCompiler}" -t "${target}" -s "${stellapath}" -i "${dycorepath}" -z
  retCode=$?
	tryExit $retCode "DYCORE BUILD"
	cd ../.. || exitError 611 ${LINENO} "Unable to go back"
}

# compile and install cosmo-pompa
doCosmo()
{
	cd cosmo-pompa/cosmo || exitError 612 ${LINENO} "Unable to change directory into cosmo-pompa/dycore"	
	test/jenkins/build.sh "${moreFlag}" -c "${compiler}" -t "${target}" -i "${cosmopath}" -x "${dycorepath}" -z
	retCode=$?
	tryExit $retCode "COSMO BUILD"
	cd ../.. || exitError 612 ${LINENO} "Unable to go back"
}

# ===================================================
# MAIN LIKE
# ===================================================

# parse command line options (pass all of them to function)
parseOptions "$@"

# check the command line options
checkOptions
printConfig

# clone
cloneTheRepos

# setup
setupBuilds

# compile and install
if [ ${doGNU} == "ON" ] ; then
	doGnuOnlyCompilation
fi

doCosmo

# end without errors
echo "####### finished: $0 $* (PID=$$ HOST=$HOSTNAME TIME=$(date '+%D %H:%M:%S'))"
exit 0

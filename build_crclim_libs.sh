#!/bin/bash

showUsage()
{
    echo "Usage: $(basename $0) -p project -t target -k ksize -f kflat -i path [-x] [-q] [-z]"
    echo ""
    echo "Arguments:"
    echo "-h             show this help message and exit"
    echo "-p project     build project: crclim or cordex"
    echo "-t target      build target: cpu or gpu"
    echo "-i path        install path for the modules (EB prefix, the directory must exist)"
    echo "-k ksize       number of k-levels (STELLA)"
    echo "-f kflat       value of k-flat (STELLA)"
    echo "-i path        install path for the modules (EB prefix, the directory must exist)"
    echo "-x bit-repro   try to build a CPU-GPU bit-reproducible model"
    echo "-q force proj  force project name without check (crCLIM or CORDEX)"
    echo "-z             clean any existing repository, reclone it, create new source archive"
    echo "               and force reinstallation"
}

showConfig()
{
    echo "==========================================================="
    echo "Compiling STELLA and the C++ Dycore as modules"
    echo "==========================================================="
    echo "Date               : $(date)"
    echo "Machine            : ${HOSTNAME}"
    echo "User               : $(whoami)"
    echo "Architecture       : ${TARGET}"
    echo "Project            : ${PROJECT}"
    echo "Force project      : ${FORCEPROJ}"
    echo "K-size             : ${KSIZE}"
    echo "K-flat             : ${KFLAT}"
    echo "Bit-reproducible   : ${BITREPROD}"
    echo "Cleanup            : ${CLEANUP}"
    echo "Install path       : ${INSTPATH}"
    echo "==========================================================="
}

parseOptions()
{
    # set defaults
    PROJECT=OFF
    TARGET=OFF
    INSTPATH=OFF
    KSIZE=OFF
    KFLAT=OFF
    CLEANUP=OFF
    FORCEPROJ=OFF
    BITREPROD=OFF
    
    while getopts ":p:t:i:k:f:xzqh" opt; do
        case $opt in
        p)
            PROJECT=$OPTARG
            ;;
        t)
            TARGET=$OPTARG
            ;;
        i)
            INSTPATH=$OPTARG
            ;;
        k)
            KSIZE=$OPTARG
            ;;
        f)
            KFLAT=$OPTARG
            ;;
        h)
            showUsage
            exit 0
            ;;
        q)
            FORCEPROJ=ON
            ;;    
        x)
            BITREPROD=ON
            ;;
        z)
            CLEANUP=ON
            ;;
        \?)
            showUsage
            exit 1
            ;;
        :)
            showUsage
            exit 1
            ;;
        esac
    done

    TARGET=${TARGET^^}
    if [ "${TARGET}" != "CPU" ] && [ "${TARGET}" != "GPU" ]
    then
        pErr "Incorrect target provided: ${TARGET}"
        pErr "Target can only be CPU or GPU"
        exit 1
    fi

    PROJECT=${PROJECT^^}
    if [ "${FORCEPROJ}" == "OFF" ]
    then
        if [ "${PROJECT}" != "CRCLIM" ] && [ "${PROJECT}" != "CORDEX" ]
        then
            pErr "Incorrect project name provided: ${PROJECT}"
            pErr "Project can only be CRCLIM or CORDEX"
            exit 1
        fi

        if [ "${PROJECT}" == "CRCLIM" ]
        then
            pWarning "Overriding K-levels and K-flats with CRCLIM values"
            KSIZE=60
            KFLAT=19
        else # -> if [ "${PROJECT}" == "CORDEX" ]
            pWarning "Overriding K-levels and K-flats with CORDEX values"
            KSIZE=40
            KFLAT=8
        fi
    else
        if [ "${KSIZE}" == "OFF" ] || [ "${KFLAT}" == "OFF" ]
        then
            pErr "Provide value for k-size and k-flat:"
            pErr "K-size: ${KSIZE}"
            pErr "K-flat: ${KFLAT}"
            exit 1
        fi
    fi

    if [ ! -d "${INSTPATH}" ]
    then
        pErr "Incorrect path provided: ${INSTPATH}"
        pErr "Please create the install directory BEFORE installing the libs"
        exit 1
    fi
}

loadModule() 
{
    module load daint-gpu
    module load EasyBuild-custom
}

exportVar()
{
    local instPath=$1
    export EASYBUILD_PREFIX=$instPath
    export EASYBUILD_BUILDPATH=/tmp/$USER/easybuild
}

getStella()
{
    local br=$1
    local org=$2
    local targz="stella.tar.gz"
    local stellaDir="stella/"

    if [ -d "${stellaDir}" ] && [ "${CLEANUP}" == "ON" ]
    then
        rm -rf "${stellaDir}"
    fi

    if [ ! -d "$stellaDir" ]
    then
        git clone -b "${br}" --single-branch  git@github.com:"${org}"/stella.git
    fi

    rm -f "${targz}"
    tar -zcf "${targz}" stella
}

getDycore()
{
    local br=$1
    local org=$2
    local targz="dycore.tar.gz"
    local cosmoDir="cosmo-pompa/"

    if [ -d "${cosmoDir}" ] && [ "${CLEANUP}" == "ON" ]
    then 
        rm -f "${targz}"
    fi

    if [ ! -d "$cosmoDir" ]
    then
        git clone -b "${br}" --single-branch git@github.com:"${org}"/cosmo-pompa.git
    fi

    rm -rf "${targz}"
    tar -zcf "${targz}" -C "${cosmoDir}" dycore VERSION STELLA_VERSION
}

sedIt()
{
    proj=$1
    targ=$2    

    template="env/template.option"
    if [ ! -f ${template} ]
    then
        pErr "File ${template} not found "
        exit 1
    fi

    stellaOpt="EBROOTSTELLA_${proj}"
    dycoreOpt="EBROOTDYCORE_${proj}_${targ}"
    
    cudaOpt=""
    if [ "${targ}" == "GPU" ]
    then
        cudaOpt="CUDA"
    fi

    optFile="Options.lib.${targ,,}"

    sed "s@%STELLADIR%@${stellaOpt}@g" "${template}" > "${optFile}"
    contOrExit "SED STELLA" $?
    sed -i "s@%DYCOREDIR%@${dycoreOpt}@g" "${optFile}"
    contOrExit "SED DYCORE" $?
    sed -i "s@%CUDA%@${cudaOpt}@g" "${optFile}"
    contOrExit "SED CUDA" $?
}

# ===========================================================
# MAIN PROGRAM
# ===========================================================
source utils.sh

parseOptions "$@"
showConfig

# ==============================================
# VERSION & VERSION SUFFIX
# ==============================================
VERSION=${PROJECT,,}
if [ "${BITREPROD}" == "ON" ]
then
    PROJECT_SUFFIX="_BITREPROD"
    VERSION_SUFFIX="-bitreprod"
else
    PROJECT_SUFFIX=""
    VERSION_SUFFIX=""
fi

stellaEBConf
dycoreEBConf

pInfo "STELLA EB: ${stellaEB}"
pInfo "DYCORE EB: ${dycoreEB}"

pInfo "Exporting variables and load modules"
exportVar "${INSTPATH}"
loadModule

# get crclim branch reprositories and create corresponding source archives
pInfo "Getting source code and creating archives"
getStella "crclim" "C2SM-RCM"
getDycore "crclim" "C2SM-RCM"

pInfo "Compiling and installing grib libraries (CSCS EB config)"
eb grib_api-1.13.1-CrayCCE-18.08.eb -r
eb libgrib1_crclim-a1e4271-CrayCCE-18.08.eb -r

ebOpt=""
if [ "${CLEANUP}" == "ON" ]
then
  ebOpt="--force"
fi

# using EB to compile Stella and the Dycore
pInfo "Compiling and installing ${PROJECT} Stella using"
pInfo "${stellaEB}"
eb ${stellaEB} ${ebOpt} -r
contOrExit "STELLA EB" $?

pInfo "Compiling and installing ${PROJECT} ${TARGET} Dycore using"
pInfo "${dycoreEB}"
eb ${dycoreEB} ${ebOpt} -r
contOrExit "DYCORE EB" $?

# prepare the new option.lib files
sedIt ${PROJECT} ${TARGET}

# prepare an info "export and load" file for the user
if [ "${TARGET}" == "CPU" ]
then
cat <<EOT > ${INSTPATH}/export_load_cpu.txt
export EASYBUILD_PREFIX=${INSTPATH}
export EASYBUILD_BUILDPATH=/tmp/${USER}/easybuild
module load daint-gpu
module load EasyBuild-custom
EOT
fi

if [ "${TARGET}" == "GPU" ]
then
cat <<EOT > ${INSTPATH}/export_load_gpu.txt
export EASYBUILD_PREFIX=${INSTPATH}
export EASYBUILD_BUILDPATH=/tmp/${USER}/easybuild
module load daint-gpu
module load EasyBuild-custom
EOT
fi

exit 0

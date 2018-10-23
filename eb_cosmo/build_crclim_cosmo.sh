#!/bin/bash

contOrExit()
{
    local info=$1
    local status=$2
    if [ "${status}" -eq 0 ]
    then
        echo "[OK] ${info}"
    else
        echo "[ERROR] ${info}"
        exit 1
    fi
}

showConfig()
{
    echo "==========================================================="
    echo "Compiling Cosmo with module libs"
    echo "==========================================================="
    echo "Date             : $(date)"
    echo "Machine          : ${HOSTNAME}"
    echo "User             : $(whoami)"
    echo "Target           : ${TARGET}"
    echo "Project          : ${PROJECT}"
    echo "Install path     : ${INSTPATH}"
    echo "==========================================================="
}

showUsage()
{
    echo "Usage: $(basename $0) -p project -t target -i path [-z]"
    echo ""
    echo "Arguments:"
    echo "-h           show this help message and exit"
    echo "-p project   build project: crclim or cordex"
    echo "-t target    build target: cpu or gpu"
    echo "-i path      install path for the modules (EB prefix, the directory must exist)"
}

parseOptions()
{
    # set defaults
    PROJECT=OFF
    CRCLIM=""
    TARGET=OFF
    CPU=""
    INSTPATH=OFF
    
    while getopts ":p:t:i:hz" opt; do
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
        h)
            showUsage
            exit 0
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

    if [ "${TARGET,,}" = "cpu" ]
    then
        CPU=ON
        TARGET="CPU"
    elif [ "${TARGET,,}" = "gpu" ]
    then
        CPU=OFF
        TARGET="GPU"
    else
        echo "Incorrect target provided: ${TARGET}"
        echo "Target can only be CPU or GPU"
        showUsage
        exit 1
    fi

    if [ "${PROJECT,,}" = "crclim" ]
    then
        CRCLIM=ON
        PROJECT="CRCLIM"
    elif [ "${PROJECT,,}" = "cordex" ]
    then
        CRCLIM=OFF
        PROJECT="CORDEX"
    else
        echo "Incorrect target provided: ${PROJECT}"
        echo "Project can only be CRCLIM or CORDEX"
        showUsage
        exit 1
    fi

    
    if [ "${INSTPATH}" == "OFF" ]
    then
        echo "[ERROR] Install path not provided: ${INSTPATH}"
        exit 1
    fi

    if [ ! -d "${INSTPATH}" ]
    then
        echo "[WARNING] Install path does not exist."
        echo "[INFO] Creating path:"
        echo "[INFO] ${INSTPATH}"
        mkdir -p ${INSTPATH}
        contOrExit "Creating Cosmo install path"
    fi
}

getPompa()
{
    local br=$1
    local org=$2
    local cosmoDir="cosmo-pompa/"

    if [ -d "$cosmoDir" ]
    then
        echo "[ERROR] The workspace has not been wiped. Please delete it manually."
        exit 1
    fi

    git clone -b "${br}" --single-branch git@github.com:"${org}"/cosmo-pompa.git
}

exportLoad()
{
    export EASYBUILD_BUILDPATH=/tmp/jenkins/easybuild
    if [ "${CRCLIM}" == "ON" ]
    then
        export EASYBUILD_PREFIX=/project/c14/install/crclim_eb/
    else
        export EASYBUILD_PREFIX=/project/c14/install/cordex_eb/
    fi    

    module load daint-gpu
    module load EasyBuild-custom
    module load DYCORE_${PROJECT}_${TARGET}
}

installPompa()
{
    local instPath=$1

    cd cosmo-pompa/cosmo
    test/jenkins/build.sh -h
    contOrExit "Trigger machine env fetch"

    cp ${EASYBUILD_PREFIX}/env.daint.sh test/jenkins/env/
    contOrExit "Copy new Daint env"

    cp ${EASYBUILD_PREFIX}/Option.lib.${TARGET,,} ./
    contOrExit "Copy new Option.lib.${TARGET,,}"

    test/jenkins/build.sh -c cray -t ${TARGET,,} -x ${EBROOTDYCORE_CRCLIM_GPU} -i ${instPath}
}

getPompa "crclim" "C2SM-RCM"
exportLoad
installPompa ${INSTPATH}

#!/bin/bash

showUsage()
{
    echo "Usage: $(basename $0) -p project -t target -k ksize -f kflat [-x (bitrepro)] [-q (force project)]"
}

showConfig()
{
    echo "==========================================================="
    echo "Generating EB files for CRCLIM and CORDEX"
    echo "==========================================================="
    echo "Date               : $(date)"
    echo "Machine            : ${HOSTNAME}"
    echo "User               : $(whoami)"
    echo "Architecture       : ${TARGET}"
    echo "CUDA               : ${CUDA}"
    echo "Project            : ${PROJECT}"
    echo "Force project      : ${FORCEPROJ}"
    echo "K-size             : ${KSIZE}"
    echo "K-flat             : ${KFLAT}"
    echo "Bit-reproducible   : ${BITREPROD}"    
    echo "Version            : ${VERSION}"
    echo "Version suffix     : ${VERSION_SUFFIX}"
    echo "==========================================================="
}

parseOptions()
{
    # set defaults
    PROJECT=OFF
    VERSION_SUFFIX=OFF
    KSIZE=OFF
    KFLAT=OFF
    BITREPROD=OFF
    FORCEPROJ=OFF
    TARGET=OFF    
    
    while getopts ":p:t:k:f:xqh" opt; do
        case $opt in
        p)
            PROJECT=$OPTARG
            ;;
        t)
            TARGET=$OPTARG
            ;;
        k)
            KSIZE=$OPTARG
            ;;
        f)
            KFLAT=$OPTARG
            ;;
        x)
            BITREPROD=ON
            ;;
        q)
            FORCEPROJ=ON
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

    # ==============================================
    # PROJECT
    # ==============================================
    echo ${FORCEPROJ}
    if [ "${FORCEPROJ}" == "ON" ]
    then
        PROJECT="${PROJECT^^}"
    else
        if [ "${PROJECT^^}" = "CRCLIM" ]
        then
            PROJECT="CRCLIM"
        elif [ "${PROJECT^^}" = "CORDEX" ]
        then
            PROJECT="CORDEX"
        else
            echo "Incorrect project name provided: ${PROJECT}"
            echo "Project can only be CRCLIM or CORDEX"
            showUsage
            exit 1
        fi
    fi

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

    # ==============================================
    # ARCHITECTURE
    # ==============================================
    if [ "${TARGET^^}" = "CPU" ]
    then
        TARGET="CPU"
        CUDA=OFF
    elif [ "${TARGET^^}" = "GPU" ]
    then
        TARGET="GPU"
        CUDA=ON
    else
        echo "Incorrect target provided: ${TARGET}"
        echo "Target can only be CPU or GPU"
        showUsage
        exit 1
    fi
}

source utils.sh

parseOptions "$@"
showConfig

stellaEBConf
dycoreEBConf

echo ${stellaEB}
echo ${dycoreEB}

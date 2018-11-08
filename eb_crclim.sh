#!/bin/bash

# CRCLIM

./eb_generator.sh -p crclim -t cpu -k 60 -f 19
./eb_generator.sh -p crclim -t gpu -k 60 -f 19
./eb_generator.sh -p crclim -t cpu -k 60 -f 19 -x
./eb_generator.sh -p crclim -t gpu -k 60 -f 19 -x

# CORDEX

./eb_generator.sh -p crclim -t cpu -k 40 -f 8
./eb_generator.sh -p crclim -t gpu -k 40 -f 8

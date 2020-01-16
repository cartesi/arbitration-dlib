#!/bin/bash

set -e

# this script will compile and migrate the contracts using truffle

# remove build directory to do a clean build
rm ./build/ -rf
truffle compile
truffle migrate --network unittests --reset

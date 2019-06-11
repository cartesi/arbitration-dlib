#!/bin/bash

# this script will compile and migrate the contracts using truffle
# and create a file `contracts.json` containing the necessary contract information for testing

# remove build directory to do a clean build
rm ./build/ -rf
sudo truffle compile
sudo truffle migrate --reset > migrate.log

# retreive contracts info from migrate log
contracts_info=`cat migrate.log |\
                grep -E "Deploying|Replacing|contract address" |\
                tr -d "> '" |\
                sed -E 's/contractaddress:(0x.+)/\"address\":\"\1\"\n},/g' |\
                sed -E 's@(Deploying|Replacing)([a-zA-Z]+)@\"\2\":{\n\"path\":\"../build/contracts/\2.json\",@g'`
                
echo {${contracts_info%?}} > contracts.json
rm migrate.log
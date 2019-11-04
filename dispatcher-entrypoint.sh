#!/bin/sh
export CARTESI_CONCERN_KEY=`cat /opt/cartesi/dispatcher/config/private_key`
mkdir -p /opt/cartesi/working_path
/opt/cartesi/arbitration_test --config_path /opt/cartesi/dispatcher/config/config.yaml --working_path /opt/cartesi/working_path

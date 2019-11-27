#!/bin/sh
export CARTESI_CONCERN_KEY=`cat /opt/cartesi/etc/keys/private_key`
/opt/cartesi/bin/arbitration_test --config_path /opt/cartesi/etc/dispatcher/config.yaml --working_path /opt/cartesi/srv/dispatcher

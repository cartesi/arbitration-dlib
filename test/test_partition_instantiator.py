# Arbritration DLib is the combination of the on-chain protocol and off-chain
# protocol that work together to resolve any disputes that might occur during the
# execution of a Cartesi DApp.

# Copyright (C) 2019 Cartesi Pte. Ltd.

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Note: This component currently has dependencies that are licensed under the GNU
# GPL, version 3, and so you should treat this component as a whole as being under
# the GPL version 3. But all Cartesi-written code in this component is licensed
# under the Apache License, version 2, or a compatible permissive license, and can
# be used independently under the Apache v2 license. After this component is
# rewritten, the entire component will be released under the Apache v2 license.


import pytest
import requests
import json
from web3 import Web3
from test_main import BaseTest

@pytest.fixture(autouse=True)
def run_between_tests(port):
    base_test = BaseTest(port)
    # Code that will run before your test, for example:
    headers = {'content-type': 'application/json'}
    payload = {"method": "evm_snapshot", "params": [], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()
    snapshot_id = response['result']
    # A test function will be run at this point
    yield
    # Code that will run after your test, for example:
    payload = {"method": "evm_revert", "params": [snapshot_id], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()

def test_instantiator(port):
    base_test = BaseTest(port)
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    address_3 = Web3.toChecksumAddress(base_test.w3.eth.accounts[2])

    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, bytes([5]), bytes([225]), 50000, 3, 55).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
    next_index = partition_logs[0]['args']['_index']
    next_index += 1

    # start from 3 to prevent revert when finalTime is not larger than zero
    for i in range(3, 12):
        # arbitrary seeds to simulate initial and final hash
        initial_hash_seed = bytes([5 + i])
        final_hash_seed = bytes([225 + i])

        if(i%2) == 0:
            # call instantiate function via transaction
            tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_3, initial_hash_seed, final_hash_seed, 50000 * i, i, 55 * i).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
            index = partition_logs[0]['args']['_index']

            error_msg = "Challenger address should be address_1"
            ret_challenger = base_test.partition_testaux.functions.getChallengerAtIndex(index).call({'from': address_1})
            assert ret_challenger == address_1, error_msg

            error_msg = "Claimer address should be address_3"
            ret_claimer = base_test.partition_testaux.functions.getClaimerAtIndex(index).call({'from': address_1})
            assert ret_claimer == address_3, error_msg

            error_msg = "Querysize should match"
            ret_query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})
            assert ret_query_size == i, error_msg
        else:
            tx_hash = base_test.partition_testaux.functions.instantiate(address_3, address_2, initial_hash_seed, final_hash_seed, 50000 * i, i + 7, 55 * i).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
            index = partition_logs[0]['args']['_index']

            error_msg = "Challenger address should be address_3"
            ret_challenger = base_test.partition_testaux.functions.getChallengerAtIndex(index).call({'from': address_1})
            assert ret_challenger == address_3, error_msg

            error_msg = "Claimer address should be address_2"
            ret_claimer = base_test.partition_testaux.functions.getClaimerAtIndex(index).call({'from': address_1})
            assert ret_claimer == address_2, error_msg

            error_msg = "Querysize should match"
            ret_query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})
            assert ret_query_size == (i + 7), error_msg

        error_msg = "Partition index should be equal to next_index"
        assert index == next_index, error_msg

        error_msg = "Round duration should be 55 * i"
        ret_round_duration = base_test.partition_testaux.functions.getRoundDurationAtIndex(index).call({'from': address_1})
        assert ret_round_duration == (55 * i), error_msg

        error_msg = "Final time should be 50000 * i"
        ret_final_time = base_test.partition_testaux.functions.getFinalTimeAtIndex(index).call({'from': address_1})
        assert ret_final_time == (50000 * i), error_msg

        error_msg = "Initial hash should match"
        ret_initial_hash = base_test.partition_testaux.functions.timeHash(index, 0).call({'from': address_1})
        assert ret_initial_hash[0:1] == initial_hash_seed, error_msg

        error_msg = "Final hash should match"
        ret_final_hash = base_test.partition_testaux.functions.timeHash(index, ret_final_time).call({'from': address_1})
        assert ret_final_hash[0:1] == final_hash_seed, error_msg

        next_index += 1
    
    
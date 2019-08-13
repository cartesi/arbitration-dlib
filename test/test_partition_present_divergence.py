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
from test_main import BaseTest, PartitionState

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

def test_partition_present_divergence(port):
    base_test = BaseTest(port)
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    # start from 1 to prevent revert when finalTime is not larger than zero
    for i in range(1, 7):
        # arbitrary seeds to simulate initial and final hash
        initial_hash_seed = bytes([3 + i])
        final_hash_seed = bytes([4 + i])

        # call instantiate function via transaction
        tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 5000 * i, 3 * i, 55 * i).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
        index = partition_logs[0]['args']['_index']

        divergence_time = base_test.partition_testaux.functions.getFinalTimeAtIndex(index).call({'from': address_1}) - i

        tx_hash = base_test.partition_testaux.functions.setTimeSubmittedAtIndex(index, divergence_time).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
        tx_hash = base_test.partition_testaux.functions.setTimeSubmittedAtIndex(index, divergence_time + 1).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
        tx_hash = base_test.partition_testaux.functions.presentDivergence(index, divergence_time).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        error_msg = "State should be DivergenceFound"
        ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
        assert ret[5][0:15].decode('utf-8') == "DivergenceFound", error_msg
    
    
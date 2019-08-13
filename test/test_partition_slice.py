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

def test_partition_slice(port):
    base_test = BaseTest(port)
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 50000, 15, 55).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
    index_1 = partition_logs[0]['args']['_index']

    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 50000, 15, 55).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
    index_2 = partition_logs[0]['args']['_index']
    
    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 50000, 15, 55).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
    index_3 = partition_logs[0]['args']['_index']

    left_point = 2
    right_point = 5

    tx_hash = base_test.partition_testaux.functions.doSlice(index_1, left_point, right_point).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    query_size = base_test.partition_testaux.functions.getQuerySize(index_1).call({'from': address_1})

    for i in range(0, query_size):
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_1, i).call({'from': address_1})

        if (left_point + i) < right_point:
            error_msg = "Queryarray[i] must be = leftPoint + i"
            assert query_array == (left_point + i), error_msg
        else:
            error_msg = "Queryarray[i] must be = rightPoint"
            assert query_array == right_point, error_msg
    
    left_point = 50
    right_point = 55

    tx_hash = base_test.partition_testaux.functions.doSlice(index_2, left_point, right_point).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    query_size = base_test.partition_testaux.functions.getQuerySize(index_2).call({'from': address_1})

    for i in range(0, query_size):
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_2, i).call({'from': address_1})

        if (left_point + i) < right_point:
            error_msg = "Queryarray[i] must be = leftPoint + i"
            assert query_array == (left_point + i), error_msg
        else:
            error_msg = "Queryarray[i] must be = rightPoint"
            assert query_array == right_point, error_msg
    
    left_point = 0
    right_point = 1

    tx_hash = base_test.partition_testaux.functions.doSlice(index_2, left_point, right_point).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    query_size = base_test.partition_testaux.functions.getQuerySize(index_2).call({'from': address_1})

    for i in range(0, query_size):
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_2, i).call({'from': address_1})

        if (left_point + i) < right_point:
            error_msg = "Queryarray[i] must be = leftPoint + i"
            assert query_array == (left_point + i), error_msg
        else:
            error_msg = "Queryarray[i] must be = rightPoint"
            assert query_array == right_point, error_msg
    
    # test else path
    left_point = 1
    right_point = 600

    tx_hash = base_test.partition_testaux.functions.doSlice(index_3, left_point, right_point).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    query_size = base_test.partition_testaux.functions.getQuerySize(index_3).call({'from': address_1})
    division_length = (int)((right_point - left_point) / (query_size - 1))

    for i in range(0, query_size - 1):
        error_msg = "slice else path"
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_3, i).call({'from': address_1})
        assert query_array == (left_point + i * division_length), error_msg
        
    # test else path
    left_point = 150
    right_point = 600

    tx_hash = base_test.partition_testaux.functions.doSlice(index_3, left_point, right_point).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    division_length = (int)((right_point - left_point) / (query_size - 1))

    for i in range(0, query_size - 1):
        error_msg = "slice else path"
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_3, i).call({'from': address_1})
        assert query_array == (left_point + i * division_length), error_msg
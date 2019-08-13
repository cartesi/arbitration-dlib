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

def test_partition_reply_query(port):
    base_test = BaseTest(port)
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 3000000, 19, 150).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
    index = partition_logs[0]['args']['_index']

    query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})

    tx_hash = base_test.partition_testaux.functions.doSlice(index, 1, query_size).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    mock_reply_array = []
    mock_posted_times = []

    for i in range(0, query_size):
        mock_reply_array.append(bytes("0123", 'utf-8'))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': address_1})
        mock_posted_times.append(query_array)

    tx_hash = base_test.partition_testaux.functions.replyQuery(index, mock_posted_times, mock_reply_array).transact({'from': address_2})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    error_msg = "CurrentState should be WaitingQuery"
    ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
    assert ret[5][0:12].decode('utf-8') == "WaitingQuery", error_msg

    for i in range(0, query_size):
        time_index = mock_posted_times[i]

        error_msg = "PostedTimes must be true"
        ret = base_test.partition_testaux.functions.getTimeSubmittedAtIndex(index, time_index).call({'from': address_1})
        assert ret, error_msg
        
        error_msg = "PostedTimes and PostedHashes should match"
        ret_hash = base_test.partition_testaux.functions.getTimeHashAtIndex(index, time_index).call({'from': address_1})
        hash_length = len(mock_reply_array[i])
        assert ret_hash[0:hash_length] == mock_reply_array[i], error_msg
        
    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 3000000, 19, 150).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
    index = partition_logs[0]['args']['_index']

    query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})

    tx_hash = base_test.partition_testaux.functions.doSlice(index, 1, query_size).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    mock_reply_array = []
    mock_posted_times = []

    for i in range(0, query_size):
        mock_reply_array.append(bytes([i]))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': address_1})
        mock_posted_times.append(query_array)

    tx_hash = base_test.partition_testaux.functions.replyQuery(index, mock_posted_times, mock_reply_array).transact({'from': address_2})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    error_msg = "CurrentState should be WaitingQuery"
    ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
    assert ret[5][0:12].decode('utf-8') == "WaitingQuery", error_msg

    for i in range(0, query_size):
        time_index = mock_posted_times[i]

        error_msg = "PostedTimes must be true"
        ret = base_test.partition_testaux.functions.getTimeSubmittedAtIndex(index, time_index).call({'from': address_1})
        assert ret, error_msg
        
        error_msg = "PostedTimes and PostedHashes should match"
        ret_hash = base_test.partition_testaux.functions.getTimeHashAtIndex(index, time_index).call({'from': address_1})
        hash_length = len(mock_reply_array[i])
        assert ret_hash[0:hash_length] == mock_reply_array[i], error_msg
    
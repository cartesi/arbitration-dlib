# Copyright (C) 2020 Cartesi Pte. Ltd.

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


import numpy as np
import pytest
import requests
import json
from web3 import Web3
from test_main import BaseTest

@pytest.fixture(autouse=True)
def run_between_tests():
    base_test = BaseTest()
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

def test_divergence_time():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    # arbitrary seeds to simulate initial and final hash
    initial_hash_seed = bytes([3])
    final_hash_seed = bytes([4])
    new_divergence_time = 5

    tx_hash = base_test.partition_testaux.functions.instantiate(provider, client, initial_hash_seed, final_hash_seed, 5000, 3, 55).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    log_to_process = tx_receipt['logs'][0]
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processLog(log_to_process)
    index = partition_logs['args']['_index']

    # call setDivergenceTimeAtIndex function via transaction
    tx_hash = base_test.partition_testaux.functions.setDivergenceTimeAtIndex(index, new_divergence_time).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "divergence time should be equal"
    ret_new_divergence_time = base_test.partition_testaux.functions.divergenceTime(index).call({'from': provider})
    assert ret_new_divergence_time == new_divergence_time, error_msg
    
def test_time_submitted():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    # arbitrary seeds to simulate initial and final hash
    initial_hash_seed = bytes([3])
    final_hash_seed = bytes([4])
    key = 3

    tx_hash = base_test.partition_testaux.functions.instantiate(provider, client, initial_hash_seed, final_hash_seed, 5000, 3, 55).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    log_to_process = tx_receipt['logs'][0]
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processLog(log_to_process)
    index = partition_logs['args']['_index']

    # call setTimeSubmittedAtIndex function via transaction
    tx_hash = base_test.partition_testaux.functions.setTimeSubmittedAtIndex(index, key).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "time submitted should be true"
    ret = base_test.partition_testaux.functions.timeSubmitted(index, key).call({'from': provider})
    assert ret, error_msg
    
def test_time_hash():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    # arbitrary seeds to simulate initial and final hash
    initial_hash_seed = bytes([3])
    final_hash_seed = bytes([4])
    new_time_hash = bytes([0x01, 0x21])
    key = 3

    tx_hash = base_test.partition_testaux.functions.instantiate(provider, client, initial_hash_seed, final_hash_seed, 5000, 3, 55).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    log_to_process = tx_receipt['logs'][0]
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processLog(log_to_process)
    index = partition_logs['args']['_index']

    # call setTimeHashAtIndex function via transaction
    tx_hash = base_test.partition_testaux.functions.setTimeHashAtIndex(index, key, new_time_hash).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "time hash should be equal"
    ret_new_time_hash = base_test.partition_testaux.functions.timeHash(index, key).call({'from': provider})
    assert ret_new_time_hash[0:2] == new_time_hash, error_msg
    
def test_query_array():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    # arbitrary seeds to simulate initial and final hash
    initial_hash_seed = bytes([3])
    final_hash_seed = bytes([4])
    query_size = 15
    query_array = np.random.randint(9999999, size=query_size).tolist()

    tx_hash = base_test.partition_testaux.functions.instantiate(provider, client, initial_hash_seed, final_hash_seed, 5000, query_size, 55).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    log_to_process = tx_receipt['logs'][0]
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processLog(log_to_process)
    index = partition_logs['args']['_index']

    for i in range(0, query_size):
        # call setQueryArrayAtIndex function via transaction
        tx_hash = base_test.partition_testaux.functions.setQueryArrayAtIndex(index, i, query_array[i]).transact({'from': provider})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
        error_msg = "query should be equal"
        ret_query = base_test.partition_testaux.functions.queryArray(index, i).call({'from': provider})
        assert ret_query == query_array[i], error_msg
    

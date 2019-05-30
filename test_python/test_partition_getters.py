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
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

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
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

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
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

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
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

    for i in range(0, query_size):
        # call setQueryArrayAtIndex function via transaction
        tx_hash = base_test.partition_testaux.functions.setQueryArrayAtIndex(index, i, query_array[i]).transact({'from': provider})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
        error_msg = "query should be equal"
        ret_query = base_test.partition_testaux.functions.queryArray(index, i).call({'from': provider})
        assert ret_query == query_array[i], error_msg
    
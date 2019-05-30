import pytest
import requests
import json
from web3 import Web3
from test_main import BaseTest, PartitionState

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

def test_partition_reply_query():
    base_test = BaseTest()
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 3000000, 19, 150).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

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
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

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
    
import time
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

def test_partition_make_query():
    base_test = BaseTest()
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    # start from 1 to prevent revert when finalTime is not larger than zero
    for i in range(1, 5):
        # arbitrary seeds to simulate initial and final hash
        initial_hash_seed = bytes([3 + i])
        final_hash_seed = bytes([4 + i])

        # call instantiate function via transaction
        tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 5000 * i, 3 * i, 55 * i).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
        index = partition_filter.get_all_entries()[0]['args']['_index']

        ret_query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})
        query_piece = ret_query_size - 2

        left_point = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, query_piece).call({'from': address_1})
        right_point = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, query_piece + 1).call({'from': address_1})

        tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingQuery.value).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
        tx_hash = base_test.partition_testaux.functions.makeQuery(index, query_piece, left_point, right_point).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        error_msg = "State should be WaitingHashes"
        ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
        assert ret[5][0:13].decode('utf-8') == "WaitingHashes", error_msg
        
        error_msg = "time of last move should be now"
        ret_time = base_test.partition_testaux.functions.getTimeOfLastMoveAtIndex(index).call({'from': address_1})
        assert 2 > (int(ret_time) - int(time.time())), error_msg
    
    
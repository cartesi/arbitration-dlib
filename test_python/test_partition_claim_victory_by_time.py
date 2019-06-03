import ast
import requests
import json
import pytest
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

def test_partition_claim_victory_by_time():
    base_test = BaseTest()
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    address_3 = Web3.toChecksumAddress(base_test.w3.eth.accounts[2])

    # start from 3 to prevent revert when finalTime is not larger than zero
    for i in range(1, 6):
        # arbitrary seeds to simulate initial and final hash
        initial_hash_seed = bytes([3 + i])
        final_hash_seed = bytes([4 + i])

        if(i%2) == 0:
            tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_3, initial_hash_seed, final_hash_seed, 5000 * i, 3 * i, 55 * i).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
            index = partition_filter.get_all_entries()[0]['args']['_index']

            tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingHashes.value).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        else:
            tx_hash = base_test.partition_testaux.functions.instantiate(address_2, address_1, initial_hash_seed, final_hash_seed, 5000 * i, 3 * i, 55 * i).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
            index = partition_filter.get_all_entries()[0]['args']['_index']

            tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingQuery.value).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        tx_hash = base_test.partition_testaux.functions.setTimeOfLastMoveAtIndex(index, 0).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        tx_hash = base_test.partition_testaux.functions.setRoundDurationAtIndex(index, 0).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        partition_filter = base_test.partition_testaux.events.ChallengeEnded.createFilter(fromBlock='latest')
        ret_index = partition_filter.get_all_entries()[0]['args']['_index']
        error_msg = "Should receive ChallengeEnded event"
        assert ret_index == index, error_msg

        if (i%2) == 0:
            error_msg = "State should be ChallengerWon"
            ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
            assert ret[5][0:13].decode('utf-8') == "ChallengerWon", error_msg
        else:
            error_msg = "State should be ClaimerWon"
            ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
            assert ret[5][0:10].decode('utf-8') == "ClaimerWon", error_msg

def test_partition_claimer_timeout():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    # arbitrary seeds to simulate initial and final hash
    initial_hash_seed = bytes([3])
    final_hash_seed = bytes([4])

    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 50000, 3, 3600).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

    headers = {'content-type': 'application/json'}
    payload = {"method": "evm_snapshot", "params": [], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()
    snapshot_id = response['result']
    payload = {"method": "evm_increaseTime", "params": [3500], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()

    error_msg = "ClaimVictoryByTime Transaction should fail, claimer has not timeout yet"
    try:
        tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

    payload = {"method": "evm_increaseTime", "params": [200], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()
    
    tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    partition_filter = base_test.partition_testaux.events.ChallengeEnded.createFilter(fromBlock='latest')
    ret_index = partition_filter.get_all_entries()[0]['args']['_index']
    error_msg = "Should receive ChallengeEnded event"
    assert ret_index == index, error_msg
    
def test_partition_challenger_timeout():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    query_size = 3

    # arbitrary seeds to simulate initial and final hash
    initial_hash_seed = bytes([3])
    final_hash_seed = bytes([4])

    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 50000, query_size, 3600).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

    mock_reply_array = []
    mock_posted_times = []

    for i in range(0, query_size):
        mock_reply_array.append(bytes("0123", 'utf-8'))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': claimer})
        mock_posted_times.append(query_array)

    tx_hash = base_test.partition_testaux.functions.replyQuery(index, mock_posted_times, mock_reply_array).transact({'from': claimer})

    headers = {'content-type': 'application/json'}
    payload = {"method": "evm_snapshot", "params": [], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()
    snapshot_id = response['result']
    payload = {"method": "evm_increaseTime", "params": [3500], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()

    error_msg = "ClaimVictoryByTime Transaction should fail, challenger has not timeout yet"
    try:
        tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': claimer})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

    payload = {"method": "evm_increaseTime", "params": [200], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()
    
    tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': claimer})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    partition_filter = base_test.partition_testaux.events.ChallengeEnded.createFilter(fromBlock='latest')
    ret_index = partition_filter.get_all_entries()[0]['args']['_index']
    error_msg = "Should receive ChallengeEnded event"
    assert ret_index == index, error_msg

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


import ast
import requests
import json
import pytest
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

def test_partition_claim_victory_by_time(port):
    base_test = BaseTest(port)
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
            partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
            index = partition_logs[0]['args']['_index']

            tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingHashes.value).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        else:
            tx_hash = base_test.partition_testaux.functions.instantiate(address_2, address_1, initial_hash_seed, final_hash_seed, 5000 * i, 3 * i, 55 * i).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
            index = partition_logs[0]['args']['_index']

            tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingQuery.value).transact({'from': address_1})
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        tx_hash = base_test.partition_testaux.functions.setTimeOfLastMoveAtIndex(index, 0).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        tx_hash = base_test.partition_testaux.functions.setRoundDurationAtIndex(index, 0).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': address_1})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        partition_logs = base_test.partition_testaux.events.ChallengeEnded().processReceipt(tx_receipt)
        ret_index = partition_logs[0]['args']['_index']
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

def test_partition_claimer_timeout(port):
    base_test = BaseTest(port)
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    # arbitrary seeds to simulate initial and final hash
    initial_hash_seed = bytes([3])
    final_hash_seed = bytes([4])

    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 50000, 3, 3600).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
    index = partition_logs[0]['args']['_index']

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
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

    payload = {"method": "evm_increaseTime", "params": [200], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()
    
    tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    partition_logs = base_test.partition_testaux.events.ChallengeEnded().processReceipt(tx_receipt)
    ret_index = partition_logs[0]['args']['_index']
    error_msg = "Should receive ChallengeEnded event"
    assert ret_index == index, error_msg
    
def test_partition_challenger_timeout(port):
    base_test = BaseTest(port)
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    query_size = 3

    # arbitrary seeds to simulate initial and final hash
    initial_hash_seed = bytes([3])
    final_hash_seed = bytes([4])

    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 50000, query_size, 3600).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processReceipt(tx_receipt)
    index = partition_logs[0]['args']['_index']

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
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

    payload = {"method": "evm_increaseTime", "params": [200], "jsonrpc": "2.0", "id": 0}
    response = requests.post(base_test.endpoint, data=json.dumps(payload), headers=headers).json()
    
    tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': claimer})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    partition_logs = base_test.partition_testaux.events.ChallengeEnded().processReceipt(tx_receipt)
    ret_index = partition_logs[0]['args']['_index']
    error_msg = "Should receive ChallengeEnded event"
    assert ret_index == index, error_msg

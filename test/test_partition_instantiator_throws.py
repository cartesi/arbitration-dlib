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


import json
import ast
import pytest
import requests
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

def test_reply_query_throws():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    log_to_process = tx_receipt['logs'][0]
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processLog(log_to_process)
    index = partition_logs['args']['_index']

    reply_array = []
    posted_times = []
    for i in range(0, 15):
        reply_array.append(bytes("0123", 'utf-8'))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': challenger})
        posted_times.append(query_array)

    tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingQuery.value).transact({'from': claimer})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
    error_msg = "ReplyQuery Transaction should fail, state is not WaitingHashes"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, posted_times, reply_array).transact({'from': claimer})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "CurrentState is not WaitingHashes, cannot replyQuery", error_msg
    else:
        raise Exception(error_msg)
        
    tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingHashes.value).transact({'from': claimer})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    wrong_posted_times = [1, 2, 3,]

    error_msg = "ReplyQuery Transaction should fail, postedTimes.length != querySize"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, wrong_posted_times, reply_array).transact({'from': claimer})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "postedTimes.length != querySize", error_msg
    else:
        raise Exception(error_msg)

    wrong_reply_array = [bytes([1]), bytes([2]), bytes([3]), bytes([4])]

    error_msg = "ReplyQuery Transaction should fail, postedHashes.length != querySize"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, posted_times, wrong_reply_array).transact({'from': claimer})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "postedHashes.length != querySize", error_msg
    else:
        raise Exception(error_msg)

    posted_times[3] = posted_times[3] + 5

    error_msg = "ReplyQuery Transaction should fail, postedTimes[i] != queryArray[i]"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, posted_times, reply_array).transact({'from': claimer})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "postedTimes[i] != queryArray[i]", error_msg
    else:
        raise Exception(error_msg)

def test_make_query_throws():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    log_to_process = tx_receipt['logs'][0]
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processLog(log_to_process)
    index = partition_logs['args']['_index']

    tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingQuery.value).transact({'from': claimer})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
    error_msg = "MakeQuery Transaction should fail, queryPiece is bigger than instance.querySize -1"
    try:
        tx_hash = base_test.partition_testaux.functions.makeQuery(index, 300, 0, 1).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "queryPiece is bigger than querySize - 1", error_msg
    else:
        raise Exception(error_msg)

    query_piece = 5
    right_point = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, query_piece + 1).call({'from': challenger})

    error_msg = "MakeQuery Transaction should fail, leftPoint != queryArray[queryPiece]"
    try:
        tx_hash = base_test.partition_testaux.functions.makeQuery(index, query_piece, 0, right_point).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "leftPoint != queryArray[queryPiece]", error_msg
    else:
        raise Exception(error_msg)
        
    left_point = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, query_piece).call({'from': challenger})

    error_msg = "MakeQuery Transaction should fail, rightPoint != queryArray[queryPiece]"
    try:
        tx_hash = base_test.partition_testaux.functions.makeQuery(index, query_piece, left_point, 13).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "rightPoint != queryArray[queryPiece]", error_msg
    else:
        raise Exception(error_msg)

def test_present_divergence_throws():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')
    divergence_time = 12

    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    log_to_process = tx_receipt['logs'][0]
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processLog(log_to_process)
    index = partition_logs['args']['_index']

    tx_hash = base_test.partition_testaux.functions.setFinalTimeAtIndex(index, 15).transact({'from': claimer})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
    error_msg = "PresentDivergence Transaction should fail, divergence time has to be less than finalTime"
    try:
        tx_hash = base_test.partition_testaux.functions.presentDivergence(index, 30).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "divergence time has to be less than finalTime", error_msg
    else:
        raise Exception(error_msg)

    tx_hash = base_test.partition_testaux.functions.setTimeSubmittedAtIndex(index, divergence_time + 1).transact({'from': claimer})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
    error_msg = "PresentDivergence Transaction should fail, divergenceTime has to have been submitted"
    try:
        tx_hash = base_test.partition_testaux.functions.presentDivergence(index, divergence_time).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "divergenceTime has to have been submitted", error_msg
    else:
        raise Exception(error_msg)
        
    divergence_time += 1
    
    error_msg = "PresentDivergence Transaction should fail, divergenceTime + 1 has to have been submitted"
    try:
        tx_hash = base_test.partition_testaux.functions.presentDivergence(index, divergence_time).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "divergenceTime + 1 has to have been submitted", error_msg
    else:
        raise Exception(error_msg)

def test_modifier():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    log_to_process = tx_receipt['logs'][0]
    partition_logs = base_test.partition_testaux.events.PartitionCreated().processLog(log_to_process)
    index = partition_logs['args']['_index']

    wrong_index = index + 1

    reply_array = []
    posted_times = []
    for i in range(0, 15):
        reply_array.append(bytes("0123", 'utf-8'))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': challenger})
        posted_times.append(query_array)
        
    error_msg = "ReplyQuery Transaction should fail, partition is not instantiated"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(wrong_index, posted_times, reply_array).transact({'from': claimer})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "Index not instantiated", error_msg
    else:
        raise Exception(error_msg)
        
    error_msg = "ReplyQuery Transaction should fail, non claimer caller"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, posted_times, reply_array).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "Cannot be called by user", error_msg
    else:
        raise Exception(error_msg)
        
def test_instantiator():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    error_msg = "Challenger and claimer have the same address"
    try:
        tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "Challenger and claimer have the same address", error_msg
    else:
        raise Exception(error_msg)
    
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    error_msg = "Final Time has to be bigger than zero"
    try:
        tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 0, 15, 55).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "Final Time has to be bigger than zero", error_msg
    else:
        raise Exception(error_msg)

    error_msg = "Query Size must be bigger than 2"
    try:
        tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 2, 55).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "Query Size must be bigger than 2", error_msg
    else:
        raise Exception(error_msg)

    error_msg = "Query Size must be less than max"
    try:
        tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 100, 55).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "Query Size must be less than max", error_msg
    else:
        raise Exception(error_msg)

    error_msg = "Round Duration has to be greater than 50 seconds"
    try:
        tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 50).transact({'from': challenger})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "Round Duration has to be greater than 50 seconds", error_msg
    else:
        raise Exception(error_msg)

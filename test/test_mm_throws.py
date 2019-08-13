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


import json
import ast
import pytest
import requests
from web3 import Web3
from test_main import BaseTest, MMState

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

def test_proveread_and_provewrite(port):
    base_test = BaseTest(port)
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']

    # call setState function via transaction(set wrong state on purpose)
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    # prepare params for the proveRead function
    fake_proof = []
    for i in range(0, 61):
        fake_proof.append(bytes("ab", 'utf-8'))

    error_msg = "ProveRead Transaction should fail, state should be WaitingProofs"
    try:
        tx_hash = base_test.mm_testaux.functions.proveRead(index, 3, bytes("initial", 'utf-8'), fake_proof).transact({'from': provider, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingProofs, cannot proveRead", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
    error_msg = "ProveWrite Transaction should fail, state should be WaitingProofs"
    try:
        tx_hash = base_test.mm_testaux.functions.proveWrite(index, 0, bytes("oldValue", 'utf-8'), bytes("newValue", 'utf-8'), fake_proof).transact({'from': provider, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingProofs, cannot proveWrite", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

def test_finish_proof_phase(port):
    base_test = BaseTest(port)
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']

    # call setState function via transaction(set wrong state on purpose)
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    error_msg = "FinishProofPhase Transaction should fail, state should be WaitingProofs"
    try:
        tx_hash = base_test.mm_testaux.functions.finishProofPhase(index).transact({'from': provider, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingProofs, cannot finishProofPhase", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
def test_finish_replay(port):
    base_test = BaseTest(port)
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']

    # call setState function via transaction(set wrong state on purpose)
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingProofs.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    error_msg = "FinishReplayPhase Transaction should fail, state should be WaitingReplay"
    try:
        tx_hash = base_test.mm_testaux.functions.finishReplayPhase(index).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingReply, cannot finishReplayPhase", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
    list_of_was_read = []
    list_of_positions = []
    list_of_values = []
    for i in range(0, 17):
        list_of_was_read.append(True)
        list_of_positions.append(i * 8)
        list_of_values.append(bytes([i]))

    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 0
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 0).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(index, list_of_was_read, list_of_positions, list_of_values).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "FinishReplayPhase Transaction should fail, historyPointer != history.length"
    try:
        tx_hash = base_test.mm_testaux.functions.finishReplayPhase(index).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert History pointer does not match length", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

def test_read_and_write(port):
    base_test = BaseTest(port)
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']
    
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    second_index = mm_logs[0]['args']['_index']
        
    list_of_was_read = []
    list_of_was_not_read = []
    list_of_positions = []
    list_of_values = []
    for i in range(0, 17):
        list_of_was_read.append(True)
        list_of_was_not_read.append(False)
        list_of_positions.append(i * 8)
        list_of_values.append(bytes([i]))
        
    # add unaligned position for testing
    list_of_was_read[16] = True
    list_of_was_not_read[16] = False
    list_of_positions[16] = 7
    list_of_values[16] = bytes([3])

    # set history pointer to 0
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 0).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 0
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(second_index, 0).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(index, list_of_was_read, list_of_positions, list_of_values).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(second_index, list_of_was_not_read, list_of_positions, list_of_values).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    position = 0

    error_msg = "Write Transaction should fail, state should be WaitingReplay"
    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, list_of_values[position]).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingReply, cannot write", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
    error_msg = "Read Transaction should fail, state should be WaitingReplay"
    try:
        tx_hash = base_test.mm_testaux.functions.read(second_index, position).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingReply, cannot read", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    tx_hash = base_test.mm_testaux.functions.setState(second_index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    # set history pointer to 16
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 16).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 16
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(second_index, 16).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    position = 7

    error_msg = "Write Transaction should fail, position not aligned"
    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, list_of_values[position]).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert Position is not aligned", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
    error_msg = "Read Transaction should fail, position not aligned"
    try:
        tx_hash = base_test.mm_testaux.functions.read(index, position).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert Position is not aligned", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']
    
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    second_index = mm_logs[0]['args']['_index']

    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    tx_hash = base_test.mm_testaux.functions.setState(second_index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    # set history pointer to 1
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 1).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 1
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(second_index, 1).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    # add incorrect values to was read list
    list_of_was_read[1] = False
    list_of_was_not_read[1] = True
    
    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(index, list_of_was_read, list_of_positions, list_of_values).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(second_index, list_of_was_not_read, list_of_positions, list_of_values).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    position = 8

    error_msg = "Write Transaction should fail, wasRead is true"
    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, list_of_values[1]).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory was not write", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
    error_msg = "Read Transaction should fail, wasRead is false"
    try:
        tx_hash = base_test.mm_testaux.functions.read(index, position).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory has not been read", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
    # set history pointer to 2
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 2).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 2
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(second_index, 2).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    position = 24

    error_msg = "Write Transaction should fail, pointInHistory.position != position"
    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, list_of_values[2]).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory's position does not match", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
    error_msg = "Read Transaction should fail, pointInHistory.position != position"
    try:
        tx_hash = base_test.mm_testaux.functions.read(index, position).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory's position does not match", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)
        
    position = 16

    error_msg = "Write Transaction should fail, pointInHistory.position != position"
    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, bytes([7])).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory's value does not match", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
    else:
        raise Exception(error_msg)

def test_instantiator(port):
    base_test = BaseTest(port)
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])

    error_msg = "Provider and client need to differ"
    try:
        tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        # assert error_dict['message'] == "VM Exception while processing transaction: revert Provider and client need to differ", error_msg
        assert error_dict['message'][0:49] == "VM Exception while processing transaction: revert", error_msg
        
    else:
        raise Exception(error_msg)
    
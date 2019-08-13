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

def test_getters(port):
    base_test = BaseTest(port)
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash = bytes("initialHash", 'utf-8')
    new_hash = bytes("newHash", 'utf-8')

    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, initial_hash).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']

    error_msg = "Provider address should match"
    ret_provider = base_test.mm_testaux.functions.provider(index).call({'from': provider})
    assert ret_provider == provider, error_msg
    
    error_msg = "Client address should match"
    ret_client = base_test.mm_testaux.functions.client(index).call({'from': provider})
    assert ret_client == client, error_msg
    
    error_msg = "Initial hash should match"
    ret_initial_hash = base_test.mm_testaux.functions.initialHash(index).call({'from': provider})
    assert ret_initial_hash[0:11] == initial_hash, error_msg

    # call setNewHashAtIndex function via transaction
    tx_hash = base_test.mm_testaux.functions.setNewHashAtIndex(index, new_hash).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "New hash should match"
    ret_new_hash = base_test.mm_testaux.functions.newHash(index).call({'from': provider})
    assert ret_new_hash[0:7] == new_hash, error_msg
    
def test_state_getters(port):
    base_test = BaseTest(port)
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash = bytes("initialHash", 'utf-8')
    new_hash = bytes("newHash", 'utf-8')

    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, initial_hash).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']

    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "state should be WaitingReplay"
    ret = base_test.mm_testaux.functions.stateIsWaitingReplay(index).call({'from': provider})
    assert ret, error_msg

    error_msg = "state shouldn't be WaitingtProofs"
    ret = base_test.mm_testaux.functions.stateIsWaitingProofs(index).call({'from': provider})
    assert not ret, error_msg

    error_msg = "state shouldn't be FinishedReplay"
    ret = base_test.mm_testaux.functions.stateIsFinishedReplay(index).call({'from': provider})
    assert not ret, error_msg

    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingProofs.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "state shouldn't be WaitingReplay"
    ret = base_test.mm_testaux.functions.stateIsWaitingReplay(index).call({'from': provider})
    assert not ret, error_msg

    error_msg = "state should be WaitingtProofs"
    ret = base_test.mm_testaux.functions.stateIsWaitingProofs(index).call({'from': provider})
    assert ret, error_msg

    error_msg = "state shouldn't be FinishedReplay"
    ret = base_test.mm_testaux.functions.stateIsFinishedReplay(index).call({'from': provider})
    assert not ret, error_msg

    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.FinishedReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "state shouldn't be WaitingReplay"
    ret = base_test.mm_testaux.functions.stateIsWaitingReplay(index).call({'from': provider})
    assert not ret, error_msg

    error_msg = "state shouldn't be WaitingtProofs"
    ret = base_test.mm_testaux.functions.stateIsWaitingProofs(index).call({'from': provider})
    assert not ret, error_msg

    error_msg = "state should be FinishedReplay"
    ret = base_test.mm_testaux.functions.stateIsFinishedReplay(index).call({'from': provider})
    assert ret, error_msg
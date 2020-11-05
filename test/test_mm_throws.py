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
from test_main import BaseTest, MMState

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

def test_proveread_and_provewrite():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    tx_hash = base_test.mm_testaux.functions.instantiate(base_test.vg_address, provider, bytes("initialHash", 'utf-8')).transact({'from': provider})
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
        tx_hash = base_test.mm_testaux.functions.proveRead(index, 3, bytes("initial", 'utf-8'), fake_proof).transact({'from': provider})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "CurrentState is not WaitingProofs, cannot proveRead", error_msg
    else:
        raise Exception(error_msg)

    error_msg = "ProveWrite Transaction should fail, state should be WaitingProofs"
    try:
        tx_hash = base_test.mm_testaux.functions.proveWrite(index, 0, bytes("oldValue", 'utf-8'), bytes("newValue", 'utf-8'), fake_proof).transact({'from': provider})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "CurrentState is not WaitingProofs, cannot proveWrite", error_msg
    else:
        raise Exception(error_msg)

def test_finish_proof_phase():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])

    tx_hash = base_test.mm_testaux.functions.instantiate(base_test.vg_address, provider, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']

    # call setState function via transaction(set wrong state on purpose)
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    error_msg = "FinishProofPhase Transaction should fail, state should be WaitingProofs"
    try:
        tx_hash = base_test.mm_testaux.functions.finishProofPhase(index).transact({'from': provider})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "CurrentState is not WaitingProofs, cannot finishProofPhase", error_msg
    else:
        raise Exception(error_msg)

def test_finish_replay():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    tx_hash = base_test.mm_testaux.functions.instantiate(base_test.vg_address, provider, bytes("initialHash", 'utf-8')).transact({'from': provider})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    mm_logs = base_test.mm_testaux.events.MemoryCreated().processReceipt(tx_receipt)
    index = mm_logs[0]['args']['_index']

    try:
        tx_hash = base_test.mm_testaux.functions.finishReplayPhase(index).transact({'from': provider})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'][50:] == "Cannot be called by user", error_msg
    else:
        raise Exception(error_msg)


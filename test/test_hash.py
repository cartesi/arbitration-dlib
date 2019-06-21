import pytest
import requests
import json
from web3 import Web3
from test_main import BaseTest

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

def test_hash(port):
    base_test = BaseTest(port)
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])

    # call instantiate function via transaction
    tx_hash = base_test.testhash.functions.testing(bytes.fromhex("012345678abcdeff"), 1234678987).transact({'from': address_1})
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    hash_logs = base_test.testhash.events.OutB32().processReceipt(tx_receipt)

    # TODO: not sure what's the assert condition for this test
    
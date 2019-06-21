# Quick Start #

install python 3.7 and pip  
run pip install pytest  
run pip install web3  
run pip install py-solc-x
run pip install numpy
run install_solc.py (only need to be run once)
run prepare_python_tests.sh  
run run_python_tests.sh  

## Note ##

***DON'T run `prepare_python_tests_coverage.sh` and `run_python_tests_coverage.sh` manually, they are supposed to be called by `solidity-coverage` only.***

# Test Example #

```python

def test_getters():
    # use BaseTest to get all contracts' address and abi
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash = bytes("initialHash", 'utf-8')
    new_hash = bytes("newHash", 'utf-8')

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, initial_hash).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    mm_filter = base_test.mm_testaux.events.MemoryCreated.createFilter(fromBlock='latest')
    index = mm_filter.get_all_entries()[0]['args']['_index']

    error_msg = "Provider address should match"
    # use call() here because no need to modify variables in the contract
    ret_provider = base_test.mm_testaux.functions.provider(index).call({'from': provider})
    assert ret_provider == provider, error_msg
    
```

# Pytest Fixture #

```python

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

```

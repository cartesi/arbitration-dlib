from web3 import Web3
from test_main import BaseTest, MMState

def test_getters():
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
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    error_msg = "New hash should match"
    ret_new_hash = base_test.mm_testaux.functions.newHash(index).call({'from': provider})
    assert ret_new_hash[0:7] == new_hash, error_msg
    
def test_state_getters():
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

    # call setState function via transaction
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
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

    # call setState function via transaction
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingProofs.value).transact({'from': provider})
    # wait for the transaction to be mined
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

    # call setState function via transaction
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.FinishedReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
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
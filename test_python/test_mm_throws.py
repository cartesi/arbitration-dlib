import json
import ast
from web3 import Web3
from test_main import BaseTest, MMState

def test_proveread_and_provewrite():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    mmfilter = base_test.mm_testaux.eventFilter('MemoryCreated', {'fromBlock': 'latest','toBlock': 'latest'})
    index = mmfilter.get_all_entries()[0]['args']['_index']

    # call setState function via transaction(set wrong state on purpose)
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    # prepare params for the proveRead function
    fake_proof = []
    for i in range(0, 61):
        fake_proof.append(bytes("ab", 'utf-8'))

    try:
        tx_hash = base_test.mm_testaux.functions.proveRead(index, 3, bytes("initial", 'utf-8'), fake_proof).transact({'from': provider, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingProofs, cannot proveRead")
    else:
        raise Exception("ProveRead Transaction should fail, state should be WaitingProofs")

        
    try:
        tx_hash = base_test.mm_testaux.functions.proveWrite(index, 0, bytes("oldValue", 'utf-8'), bytes("newValue", 'utf-8'), fake_proof).transact({'from': provider, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingProofs, cannot proveWrite")
    else:
        raise Exception("ProveWrite Transaction should fail, state should be WaitingProofs")

def test_finish_proof_phase():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    mmfilter = base_test.mm_testaux.eventFilter('MemoryCreated', {'fromBlock': 'latest','toBlock': 'latest'})
    index = mmfilter.get_all_entries()[0]['args']['_index']

    # call setState function via transaction(set wrong state on purpose)
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    try:
        tx_hash = base_test.mm_testaux.functions.finishProofPhase(index).transact({'from': provider, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingProofs, cannot finishProofPhase")
    else:
        raise Exception("Transaction should fail, state should be WaitinProofs")
        
def test_finish_replay():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    mmfilter = base_test.mm_testaux.eventFilter('MemoryCreated', {'fromBlock': 'latest','toBlock': 'latest'})
    index = mmfilter.get_all_entries()[0]['args']['_index']

    # call setState function via transaction(set wrong state on purpose)
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingProofs.value).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    try:
        tx_hash = base_test.mm_testaux.functions.finishReplayPhase(index).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingReply, cannot finishReplayPhase")
    else:
        raise Exception("Transaction should fail, state should be WaitingReplay")
        
    list_of_was_read = []
    list_of_positions = []
    list_of_values = []
    for i in range(0, 17):
        list_of_was_read.append(True)
        list_of_positions.append(i * 8)
        list_of_values.append(bytes([i]))

    # call setState function via transaction
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 0
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 0).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(index, list_of_was_read, list_of_positions, list_of_values).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
     
    try:
        tx_hash = base_test.mm_testaux.functions.finishReplayPhase(index).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert History pointer does not match length")
    else:
        raise Exception("Transaction should fail, historyPointer != history.length")

def test_read_and_write():
    base_test = BaseTest()
    provider = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    client = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    mmfilter = base_test.mm_testaux.eventFilter('MemoryCreated', {'fromBlock': 'latest','toBlock': 'latest'})
    index = mmfilter.get_all_entries()[0]['args']['_index']
    
    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    mmfilter = base_test.mm_testaux.eventFilter('MemoryCreated', {'fromBlock': 'latest','toBlock': 'latest'})
    second_index = mmfilter.get_all_entries()[0]['args']['_index']
        
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
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 0
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(second_index, 0).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(index, list_of_was_read, list_of_positions, list_of_values).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(second_index, list_of_was_not_read, list_of_positions, list_of_values).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    position = 0

    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, list_of_values[position]).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingReply, cannot write")
    else:
        raise Exception("Write Transaction should fail, state should be WaitingReplay")
        
    try:
        tx_hash = base_test.mm_testaux.functions.read(second_index, position).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingReply, cannot read")
    else:
        raise Exception("Read Transaction should fail, state should be WaitingReplay")

    # call setState function via transaction
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # call setState function via transaction
    tx_hash = base_test.mm_testaux.functions.setState(second_index, MMState.WaitingReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    # set history pointer to 16
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 16).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 16
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(second_index, 16).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    position = 7

    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, list_of_values[position]).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert Position is not aligned")
    else:
        raise Exception("Write Transaction should fail, position not aligned")
        
    try:
        tx_hash = base_test.mm_testaux.functions.read(index, position).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert Position is not aligned")
    else:
        raise Exception("Read Transaction should fail, position not aligned")

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    mmfilter = base_test.mm_testaux.eventFilter('MemoryCreated', {'fromBlock': 'latest','toBlock': 'latest'})
    index = mmfilter.get_all_entries()[0]['args']['_index']
    
    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.mm_testaux.functions.instantiate(provider, client, bytes("initialHash", 'utf-8')).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    mmfilter = base_test.mm_testaux.eventFilter('MemoryCreated', {'fromBlock': 'latest','toBlock': 'latest'})
    second_index = mmfilter.get_all_entries()[0]['args']['_index']

    # call setState function via transaction
    tx_hash = base_test.mm_testaux.functions.setState(index, MMState.WaitingReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # call setState function via transaction
    tx_hash = base_test.mm_testaux.functions.setState(second_index, MMState.WaitingReplay.value).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    # set history pointer to 1
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 1).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 1
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(second_index, 1).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    
    # add incorrect values to was read list
    list_of_was_read[1] = False
    list_of_was_not_read[1] = True
    
    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(index, list_of_was_read, list_of_positions, list_of_values).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # create ReadWrites and add it to the history
    tx_hash = base_test.mm_testaux.functions.setHistoryAtIndex(second_index, list_of_was_not_read, list_of_positions, list_of_values).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    position = 8

    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, list_of_values[1]).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory was not write")
    else:
        raise Exception("Write Transaction should fail, wasRead is true")
        
    try:
        tx_hash = base_test.mm_testaux.functions.read(index, position).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory has not been read")
    else:
        raise Exception("Read Transaction should fail, wasRead is false")
        
    # set history pointer to 2
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(index, 2).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # set history pointer to 2
    tx_hash = base_test.mm_testaux.functions.setHistoryPointerAtIndex(second_index, 2).transact({'from': provider})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    position = 24

    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, list_of_values[2]).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory's position does not match")
    else:
        raise Exception("Write Transaction should fail, pointInHistory.position != position")
        
    try:
        tx_hash = base_test.mm_testaux.functions.read(index, position).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory's position does not match")
    else:
        raise Exception("Read Transaction should fail, pointInHistory.position != position")
        
    position = 16

    try:
        tx_hash = base_test.mm_testaux.functions.write(second_index, position, bytes([7])).transact({'from': client, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert(error_dict['message'] == "VM Exception while processing transaction: revert PointInHistory's value does not match")
    else:
        raise Exception("Write Transaction should fail, pointInHistory.position != position")
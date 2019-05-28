import json
import ast
from web3 import Web3
from test_main import BaseTest, PartitionState

def test_reply_query_throws():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

    reply_array = []
    posted_times = []
    for i in range(0, 15):
        reply_array.append(bytes("0123", 'utf-8'))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': challenger})
        posted_times.append(query_array)

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingQuery.value).transact({'from': claimer})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
    error_msg = "ReplyQuery Transaction should fail, state is not WaitingHashes"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, posted_times, reply_array).transact({'from': claimer, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert CurrentState is not WaitingHashes, cannot replayQuery", error_msg
    else:
        raise Exception(error_msg)
        
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingHashes.value).transact({'from': claimer})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    wrong_posted_times = [1, 2, 3,]

    error_msg = "ReplyQuery Transaction should fail, postedTimes.length != querySize"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, wrong_posted_times, reply_array).transact({'from': claimer, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert postedTimes.length != querySize", error_msg
    else:
        raise Exception(error_msg)

    wrong_reply_array = [bytes([1]), bytes([2]), bytes([3]), bytes([4])]

    error_msg = "ReplyQuery Transaction should fail, postedHashes.length != querySize"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, posted_times, wrong_reply_array).transact({'from': claimer, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert postedHashes.length != querySize", error_msg
    else:
        raise Exception(error_msg)

    posted_times[3] = posted_times[3] + 5

    error_msg = "ReplyQuery Transaction should fail, postedTimes[i] != queryArray[i]"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, posted_times, reply_array).transact({'from': claimer, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert postedTimes[i] != queryArray[i]", error_msg
    else:
        raise Exception(error_msg)

def test_make_query_throws():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingQuery.value).transact({'from': claimer})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
    error_msg = "MakeQuery Transaction should fail, queryPiece is bigger than instance.querySize -1"
    try:
        tx_hash = base_test.partition_testaux.functions.makeQuery(index, 300, 0, 1).transact({'from': challenger, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert queryPiece is bigger than querySize - 1", error_msg
    else:
        raise Exception(error_msg)

    query_piece = 5
    right_point = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, query_piece + 1).call({'from': challenger})

    error_msg = "MakeQuery Transaction should fail, leftPoint != queryArray[queryPiece]"
    try:
        tx_hash = base_test.partition_testaux.functions.makeQuery(index, query_piece, 0, right_point).transact({'from': challenger, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert leftPoint != queryArray[queryPiece]", error_msg
    else:
        raise Exception(error_msg)
        
    left_point = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, query_piece).call({'from': challenger})

    error_msg = "MakeQuery Transaction should fail, rightPoint != queryArray[queryPiece]"
    try:
        tx_hash = base_test.partition_testaux.functions.makeQuery(index, query_piece, left_point, 13).transact({'from': challenger, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert rightPoint != queryArray[queryPiece]", error_msg
    else:
        raise Exception(error_msg)

def test_present_divergence_throws():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')
    divergence_time = 12

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.setFinalTimeAtIndex(index, 15).transact({'from': claimer})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
    error_msg = "PresentDivergence Transaction should fail, divergence time has to be less than finalTime"
    try:
        tx_hash = base_test.partition_testaux.functions.presentDivergence(index, 30).transact({'from': challenger, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert divergence time has to be less than finalTime", error_msg
    else:
        raise Exception(error_msg)

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.setTimeSubmittedAtIndex(index, divergence_time + 1).transact({'from': claimer})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        
    error_msg = "PresentDivergence Transaction should fail, divergenceTime has to have been submitted"
    try:
        tx_hash = base_test.partition_testaux.functions.presentDivergence(index, divergence_time).transact({'from': challenger, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert divergenceTime has to have been submitted", error_msg
    else:
        raise Exception(error_msg)
        
    divergence_time += 1
    
    error_msg = "PresentDivergence Transaction should fail, divergenceTime + 1 has to have been submitted"
    try:
        tx_hash = base_test.partition_testaux.functions.presentDivergence(index, divergence_time).transact({'from': challenger, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert divergenceTime + 1 has to have been submitted", error_msg
    else:
        raise Exception(error_msg)

def test_modifier():
    base_test = BaseTest()
    challenger = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    claimer = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(challenger, claimer, initial_hash_seed, final_hash_seed, 5000, 15, 55).transact({'from': challenger})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']
    wrong_index = index + 1

    reply_array = []
    posted_times = []
    for i in range(0, 15):
        reply_array.append(bytes("0123", 'utf-8'))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': challenger})
        posted_times.append(query_array)
        
    error_msg = "ReplyQuery Transaction should fail, partition is not instantiated"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(wrong_index, posted_times, reply_array).transact({'from': claimer, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert Index not instantiated", error_msg
    else:
        raise Exception(error_msg)
        
    error_msg = "ReplyQuery Transaction should fail, non claimer caller"
    try:
        tx_hash = base_test.partition_testaux.functions.replyQuery(index, posted_times, reply_array).transact({'from': challenger, 'gas': 2000000})
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    except ValueError as e:
        error_dict = ast.literal_eval(str(e))
        assert error_dict['message'] == "VM Exception while processing transaction: revert Cannot be called by user", error_msg
    else:
        raise Exception(error_msg)
        
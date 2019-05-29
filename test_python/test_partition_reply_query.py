from web3 import Web3
from test_main import BaseTest, PartitionState

def test_partition_reply_query():
    base_test = BaseTest()
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 3000000, 19, 150).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

    query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.doSlice(index, 1, query_size).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    mock_reply_array = []
    mock_posted_times = []

    for i in range(0, query_size):
        mock_reply_array.append(bytes("0123", 'utf-8'))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': address_1})
        mock_posted_times.append(query_array)

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.replyQuery(index, mock_posted_times, mock_reply_array).transact({'from': address_2})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    error_msg = "CurrentState should be WaitingQuery"
    ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
    assert ret[5][0:12].decode('utf-8') == "WaitingQuery", error_msg

    for i in range(0, query_size):
        time_index = mock_posted_times[i]

        error_msg = "PostedTimes must be true"
        ret = base_test.partition_testaux.functions.getTimeSubmittedAtIndex(index, time_index).call({'from': address_1})
        assert ret, error_msg
        
        error_msg = "PostedTimes and PostedHashes should match"
        ret_hash = base_test.partition_testaux.functions.getTimeHashAtIndex(index, time_index).call({'from': address_1})
        hash_length = len(mock_reply_array[i])
        assert ret_hash[0:hash_length] == mock_reply_array[i], error_msg
        
    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 3000000, 19, 150).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index = partition_filter.get_all_entries()[0]['args']['_index']

    query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.doSlice(index, 1, query_size).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    mock_reply_array = []
    mock_posted_times = []

    for i in range(0, query_size):
        mock_reply_array.append(bytes([i]))
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index, i).call({'from': address_1})
        mock_posted_times.append(query_array)

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.replyQuery(index, mock_posted_times, mock_reply_array).transact({'from': address_2})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    error_msg = "CurrentState should be WaitingQuery"
    ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
    assert ret[5][0:12].decode('utf-8') == "WaitingQuery", error_msg

    for i in range(0, query_size):
        time_index = mock_posted_times[i]

        error_msg = "PostedTimes must be true"
        ret = base_test.partition_testaux.functions.getTimeSubmittedAtIndex(index, time_index).call({'from': address_1})
        assert ret, error_msg
        
        error_msg = "PostedTimes and PostedHashes should match"
        ret_hash = base_test.partition_testaux.functions.getTimeHashAtIndex(index, time_index).call({'from': address_1})
        hash_length = len(mock_reply_array[i])
        assert ret_hash[0:hash_length] == mock_reply_array[i], error_msg
    
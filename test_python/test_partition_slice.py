from web3 import Web3
from test_main import BaseTest, PartitionState

def test_partition_slice():
    base_test = BaseTest()
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    initial_hash_seed = bytes("initialHash", 'utf-8')
    final_hash_seed = bytes("finalHash", 'utf-8')

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 50000, 15, 55).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index_1 = partition_filter.get_all_entries()[0]['args']['_index']

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 50000, 15, 55).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index_2 = partition_filter.get_all_entries()[0]['args']['_index']
    
    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, initial_hash_seed, final_hash_seed, 50000, 15, 55).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    index_3 = partition_filter.get_all_entries()[0]['args']['_index']

    left_point = 2
    right_point = 5

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.doSlice(index_1, left_point, right_point).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    query_size = base_test.partition_testaux.functions.getQuerySize(index_1).call({'from': address_1})

    for i in range(0, query_size):
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_1, i).call({'from': address_1})

        if (left_point + i) < right_point:
            error_msg = "Queryarray[i] must be = leftPoint + i"
            assert query_array == (left_point + i), error_msg
        else:
            error_msg = "Queryarray[i] must be = rightPoint"
            assert query_array == right_point, error_msg
    
    left_point = 50
    right_point = 55

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.doSlice(index_2, left_point, right_point).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    query_size = base_test.partition_testaux.functions.getQuerySize(index_2).call({'from': address_1})

    for i in range(0, query_size):
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_2, i).call({'from': address_1})

        if (left_point + i) < right_point:
            error_msg = "Queryarray[i] must be = leftPoint + i"
            assert query_array == (left_point + i), error_msg
        else:
            error_msg = "Queryarray[i] must be = rightPoint"
            assert query_array == right_point, error_msg
    
    left_point = 0
    right_point = 1

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.doSlice(index_2, left_point, right_point).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    query_size = base_test.partition_testaux.functions.getQuerySize(index_2).call({'from': address_1})

    for i in range(0, query_size):
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_2, i).call({'from': address_1})

        if (left_point + i) < right_point:
            error_msg = "Queryarray[i] must be = leftPoint + i"
            assert query_array == (left_point + i), error_msg
        else:
            error_msg = "Queryarray[i] must be = rightPoint"
            assert query_array == right_point, error_msg
    
    # test else path
    left_point = 1
    right_point = 600

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.doSlice(index_3, left_point, right_point).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    query_size = base_test.partition_testaux.functions.getQuerySize(index_3).call({'from': address_1})
    division_length = (int)((right_point - left_point) / (query_size - 1))

    for i in range(0, query_size - 1):
        error_msg = "slice else path"
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_3, i).call({'from': address_1})
        assert query_array == (left_point + i * division_length), error_msg
        
    # test else path
    left_point = 150
    right_point = 600

    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.doSlice(index_3, left_point, right_point).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

    division_length = (int)((right_point - left_point) / (query_size - 1))

    for i in range(0, query_size - 1):
        error_msg = "slice else path"
        query_array = base_test.partition_testaux.functions.getQueryArrayAtIndex(index_3, i).call({'from': address_1})
        assert query_array == (left_point + i * division_length), error_msg
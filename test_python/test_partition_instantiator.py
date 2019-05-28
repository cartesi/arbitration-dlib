from web3 import Web3
from test_main import BaseTest

def test_instantiator():
    base_test = BaseTest()
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    address_3 = Web3.toChecksumAddress(base_test.w3.eth.accounts[2])

    # call instantiate function via transaction
    # didn't use call() because it doesn't really send transaction to the blockchain
    tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_2, bytes([5]), bytes([225]), 50000, 3, 55).transact({'from': address_1})
    # wait for the transaction to be mined
    tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
    # get the returned index via the event filter
    partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
    next_index = partition_filter.get_all_entries()[0]['args']['_index']
    next_index += 1

    # start from 3 to prevent revert when finalTime is not larger than zero
    for i in range(3, 12):
        # arbitrary seeds to simulate initial and final hash
        initial_hash_seed = bytes([5 + i])
        final_hash_seed = bytes([225 + i])

        if(i%2) == 0:
            # call instantiate function via transaction
            # didn't use call() because it doesn't really send transaction to the blockchain
            tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_3, initial_hash_seed, final_hash_seed, 50000 * i, i, 55 * i).transact({'from': address_1})
            # wait for the transaction to be mined
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            # get the returned index via the event filter
            partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
            index = partition_filter.get_all_entries()[0]['args']['_index']

            error_msg = "Challenger address should be address_1"
            ret_challenger = base_test.partition_testaux.functions.getChallengerAtIndex(index).call({'from': address_1})
            assert ret_challenger == address_1, error_msg

            error_msg = "Claimer address should be address_3"
            ret_claimer = base_test.partition_testaux.functions.getClaimerAtIndex(index).call({'from': address_1})
            assert ret_claimer == address_3, error_msg

            error_msg = "Querysize should match"
            ret_query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})
            assert ret_query_size == i, error_msg
        else:
            # didn't use call() because it doesn't really send transaction to the blockchain
            tx_hash = base_test.partition_testaux.functions.instantiate(address_3, address_2, initial_hash_seed, final_hash_seed, 50000 * i, i + 7, 55 * i).transact({'from': address_1})
            # wait for the transaction to be mined
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            # get the returned index via the event filter
            partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
            index = partition_filter.get_all_entries()[0]['args']['_index']

            error_msg = "Challenger address should be address_3"
            ret_challenger = base_test.partition_testaux.functions.getChallengerAtIndex(index).call({'from': address_1})
            assert ret_challenger == address_3, error_msg

            error_msg = "Claimer address should be address_2"
            ret_claimer = base_test.partition_testaux.functions.getClaimerAtIndex(index).call({'from': address_1})
            assert ret_claimer == address_2, error_msg

            error_msg = "Querysize should match"
            ret_query_size = base_test.partition_testaux.functions.getQuerySize(index).call({'from': address_1})
            assert ret_query_size == (i + 7), error_msg

        error_msg = "Partition index should be equal to next_index"
        assert index == next_index, error_msg

        error_msg = "Round duration should be 55 * i"
        ret_round_duration = base_test.partition_testaux.functions.getRoundDurationAtIndex(index).call({'from': address_1})
        assert ret_round_duration == (55 * i), error_msg

        error_msg = "Final time should be 50000 * i"
        ret_final_time = base_test.partition_testaux.functions.getFinalTimeAtIndex(index).call({'from': address_1})
        assert ret_final_time == (50000 * i), error_msg

        error_msg = "Initial hash should match"
        ret_initial_hash = base_test.partition_testaux.functions.timeHash(index, 0).call({'from': address_1})
        assert ret_initial_hash[0:1] == initial_hash_seed, error_msg

        error_msg = "Final hash should match"
        ret_final_hash = base_test.partition_testaux.functions.timeHash(index, ret_final_time).call({'from': address_1})
        assert ret_final_hash[0:1] == final_hash_seed, error_msg

        next_index += 1
    
    
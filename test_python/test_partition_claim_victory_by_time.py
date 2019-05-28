from web3 import Web3
from test_main import BaseTest, PartitionState

def test_partition_claim_victory_by_time():
    base_test = BaseTest()
    address_1 = Web3.toChecksumAddress(base_test.w3.eth.accounts[0])
    address_2 = Web3.toChecksumAddress(base_test.w3.eth.accounts[1])
    address_3 = Web3.toChecksumAddress(base_test.w3.eth.accounts[2])

    # start from 3 to prevent revert when finalTime is not larger than zero
    for i in range(1, 6):
        # arbitrary seeds to simulate initial and final hash
        initial_hash_seed = bytes([3 + i])
        final_hash_seed = bytes([4 + i])

        if(i%2) == 0:
            # call instantiate function via transaction
            # didn't use call() because it doesn't really send transaction to the blockchain
            tx_hash = base_test.partition_testaux.functions.instantiate(address_1, address_3, initial_hash_seed, final_hash_seed, 5000 * i, 3 * i, 55 * i).transact({'from': address_1})
            # wait for the transaction to be mined
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            # get the returned index via the event filter
            partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
            index = partition_filter.get_all_entries()[0]['args']['_index']

            # didn't use call() because it doesn't really send transaction to the blockchain
            tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingHashes.value).transact({'from': address_1})
            # wait for the transaction to be mined
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
        else:
            # didn't use call() because it doesn't really send transaction to the blockchain
            tx_hash = base_test.partition_testaux.functions.instantiate(address_2, address_1, initial_hash_seed, final_hash_seed, 5000 * i, 3 * i, 55 * i).transact({'from': address_1})
            # wait for the transaction to be mined
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)
            # get the returned index via the event filter
            partition_filter = base_test.partition_testaux.events.PartitionCreated.createFilter(fromBlock='latest')
            index = partition_filter.get_all_entries()[0]['args']['_index']

            # didn't use call() because it doesn't really send transaction to the blockchain
            tx_hash = base_test.partition_testaux.functions.setState(index, PartitionState.WaitingQuery.value).transact({'from': address_1})
            # wait for the transaction to be mined
            tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        # didn't use call() because it doesn't really send transaction to the blockchain
        tx_hash = base_test.partition_testaux.functions.setTimeOfLastMoveAtIndex(index, 0).transact({'from': address_1})
        # wait for the transaction to be mined
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        # didn't use call() because it doesn't really send transaction to the blockchain
        tx_hash = base_test.partition_testaux.functions.setRoundDurationAtIndex(index, 0).transact({'from': address_1})
        # wait for the transaction to be mined
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        # didn't use call() because it doesn't really send transaction to the blockchain
        tx_hash = base_test.partition_testaux.functions.claimVictoryByTime(index).transact({'from': address_1})
        # wait for the transaction to be mined
        tx_receipt = base_test.w3.eth.waitForTransactionReceipt(tx_hash)

        if (i%2) == 0:
            error_msg = "State should be ChallengerWon"
            ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
            assert ret[5][0:13].decode('utf-8') == "ChallengerWon", error_msg
        else:
            error_msg = "State should be ClaimerWon"
            ret = base_test.partition_testaux.functions.getState(index).call({'from': address_1})
            assert ret[5][0:10].decode('utf-8') == "ClaimerWon", error_msg
    
    
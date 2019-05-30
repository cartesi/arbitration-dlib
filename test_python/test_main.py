import os
import json
from enum import Enum
from web3 import Web3
from solcx import install_solc
from solcx import get_solc_version, set_solc_version, compile_files

class MMState(Enum):
    WaitingProofs = 0
    WaitingReplay = 1
    FinishedReplay = 2
    
class ComputeState(Enum):
    WaitingClaim = 0
    WaitingConfirmation = 1
    ClaimerMissedDeadline = 2
    WaitingChallenge = 3
    ChallengerWon = 4
    ClaimerWon = 5
    ConsensusResult = 6
    
class PartitionState(Enum):
    WaitingQuery = 0
    WaitingHashes = 1
    ChallengerWon = 2
    ClaimerWon = 3
    DivergenceFound = 4
    
class VGState(Enum):
    WaitPartition = 0
    WaitMemoryProveValues = 1
    FinishedClaimerWon = 2
    FinishedChallengerWon = 3

class BaseTest:

    def __init__(self):
        get_solc_version()

        #Connecting to node
        self.endpoint = "http://127.0.0.1:8545"
        self.w3 = Web3(Web3.HTTPProvider(self.endpoint))

        if (self.w3.isConnected()):
            print("Connected to node\n")
        else:
            print("Couldn't connect to node, exiting")
            sys.exit(1)

        #step_compiled = compile_files([directory + 'Step.sol'])
        #loading deployed contract address and json file path
        with open('../contracts.json') as json_file:
            self.contracts = json.load(json_file)

        with open(self.contracts['MMInstantiator']['path']) as json_file:
            self.mm_data = json.load(json_file)
        with open(self.contracts['SimpleMemoryInstantiator']['path']) as json_file:
            self.simplemm_data = json.load(json_file)
        with open(self.contracts['Hasher']['path']) as json_file:
            self.hasher_data = json.load(json_file)
        with open(self.contracts['PartitionInstantiator']['path']) as json_file:
            self.partition_data = json.load(json_file)
        with open(self.contracts['VGInstantiator']['path']) as json_file:
            self.vg_data = json.load(json_file)
        with open(self.contracts['ComputeInstantiator']['path']) as json_file:
            self.compute_data = json.load(json_file)
        with open(self.contracts['TestHash']['path']) as json_file:
            self.testhash_data = json.load(json_file)

        with open(self.contracts['MMInstantiatorTestAux']['path']) as json_file:
            self.mm_testaux_data = json.load(json_file)
        with open(self.contracts['PartitionTestAux']['path']) as json_file:
            self.partition_testaux_data = json.load(json_file)

        self.mm = self.w3.eth.contract(address=self.contracts['MMInstantiator']['address'], abi=self.mm_data['abi'])
        self.simplemm = self.w3.eth.contract(address=self.contracts['SimpleMemoryInstantiator']['address'], abi=self.simplemm_data['abi'])
        self.hasher = self.w3.eth.contract(address=self.contracts['Hasher']['address'], abi=self.hasher_data['abi'])
        self.partition = self.w3.eth.contract(address=self.contracts['PartitionInstantiator']['address'], abi=self.partition_data['abi'])
        self.vg = self.w3.eth.contract(address=self.contracts['VGInstantiator']['address'], abi=self.vg_data['abi'])
        self.compute = self.w3.eth.contract(address=self.contracts['ComputeInstantiator']['address'], abi=self.compute_data['abi'])
        self.testhash = self.w3.eth.contract(address=self.contracts['TestHash']['address'], abi=self.testhash_data['abi'])
        self.mm_testaux = self.w3.eth.contract(address=self.contracts['MMInstantiatorTestAux']['address'], abi=self.mm_testaux_data['abi'])
        self.partition_testaux = self.w3.eth.contract(address=self.contracts['PartitionTestAux']['address'], abi=self.partition_testaux_data['abi'])

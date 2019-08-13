# Arbritration DLib is the combination of the on-chain protocol and off-chain
# protocol that work together to resolve any disputes that might occur during the
# execution of a Cartesi DApp.

# Copyright (C) 2019 Cartesi Pte. Ltd.

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Note: This component currently has dependencies that are licensed under the GNU
# GPL, version 3, and so you should treat this component as a whole as being under
# the GPL version 3. But all Cartesi-written code in this component is licensed
# under the Apache License, version 2, or a compatible permissive license, and can
# be used independently under the Apache v2 license. After this component is
# rewritten, the entire component will be released under the Apache v2 license.


import os
import json
from enum import Enum
from web3 import Web3
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

    def __init__(self, port):
        get_solc_version()

        #Connecting to node
        self.port = port
        self.endpoint = "http://127.0.0.1:" + port
        self.w3 = Web3(Web3.HTTPProvider(self.endpoint))

        if (self.w3.isConnected()):
            print("Connected to node\n")
        else:
            print("Couldn't connect to node, exiting")
            sys.exit(1)

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

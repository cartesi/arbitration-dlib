# Copyright (C) 2020 Cartesi Pte. Ltd.

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
from web3.auto import w3

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

        assert w3.isConnected(), "Couldn't connect to node"

        self.endpoint = "http://127.0.0.1:8545"
        self.w3 = w3
        networkId = w3.net.version

        #loading deployed contract address and json file path

        with open('../build/contracts/MMInstantiator.json') as json_file:
            mm_data = json.load(json_file)
            self.mm = w3.eth.contract(address=mm_data['networks'][networkId]['address'], abi=mm_data['abi'])
        with open('../build/contracts/SimpleMemoryInstantiator.json') as json_file:
            simplemm_data = json.load(json_file)
            self.mm = w3.eth.contract(address=mm_data['networks'][networkId]['address'], abi=mm_data['abi'])
        with open('../build/contracts/Hasher.json') as json_file:
            hasher_data = json.load(json_file)
            self.hasher = w3.eth.contract(address=hasher_data['networks'][networkId]['address'], abi=hasher_data['abi'])
        with open('../build/contracts/PartitionInstantiator.json') as json_file:
            partition_data = json.load(json_file)
            self.partition = w3.eth.contract(address=partition_data['networks'][networkId]['address'], abi=partition_data['abi'])
        with open('../build/contracts/VGInstantiator.json') as json_file:
            vg_data = json.load(json_file)
            self.vg = w3.eth.contract(address=vg_data['networks'][networkId]['address'], abi=vg_data['abi'])
        with open('../build/contracts/ComputeInstantiator.json') as json_file:
            compute_data = json.load(json_file)
            self.compute = w3.eth.contract(address=compute_data['networks'][networkId]['address'], abi=compute_data['abi'])
        with open('../build/contracts/TestHash.json') as json_file:
            testhash_data = json.load(json_file)
            self.testhash = w3.eth.contract(address=testhash_data['networks'][networkId]['address'], abi=testhash_data['abi'])

        with open('../build/contracts/MMInstantiatorTestAux.json') as json_file:
            mm_testaux_data = json.load(json_file)
            self.mm_testaux = w3.eth.contract(address=mm_testaux_data['networks'][networkId]['address'], abi=mm_testaux_data['abi'])
        with open('../build/contracts/PartitionTestAux.json') as json_file:
            partition_testaux_data = json.load(json_file)
            self.partition_testaux = w3.eth.contract(address=partition_testaux_data['networks'][networkId]['address'], abi=partition_testaux_data['abi'])


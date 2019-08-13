// Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.
//
// Copyright 2019 Cartesi Pte. Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.



pragma solidity ^0.5.0;
import "../MMInstantiator.sol";


contract MMInstantiatorTestAux is MMInstantiator {

    function setState(uint index, state toState) public {
        instance[index].currentState = toState;
    }

    function setHistoryPointerAtIndex(uint index, uint pointer) public {
        instance[index].historyPointer = pointer;
    }

    function setHistoryAtIndex(
        uint index,
        bool[] memory listOfWasRead,
        uint64[] memory listOfPositions,
        bytes8[] memory listOfValues) public
    {
        for (uint i = 0; i < listOfWasRead.length; i++) {
            ReadWrite memory dummyReadWrite;
            dummyReadWrite.wasRead = listOfWasRead[i];
            dummyReadWrite.position = listOfPositions[i];
            dummyReadWrite.value = listOfValues[i];

            instance[index].history.push(dummyReadWrite);
        }
    }

    function setNewHashAtIndex(uint index, bytes32 newHash) public {
        instance[index].newHash = newHash;
    }

    //Wrapper because ThrowProxy contract do not work with return values
    //https://github.com/trufflesuite/truffle/issues/1001
    function readWrapper(uint index, uint64 position) public {
        read(index, position);
    }
}

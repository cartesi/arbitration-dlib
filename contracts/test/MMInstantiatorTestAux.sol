// Copyright (C) 2020 Cartesi Pte. Ltd.

// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.

// This program is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
// PARTICULAR PURPOSE. See the GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Note: This component currently has dependencies that are licensed under the GNU
// GPL, version 3, and so you should treat this component as a whole as being under
// the GPL version 3. But all Cartesi-written code in this component is licensed
// under the Apache License, version 2, or a compatible permissive license, and can
// be used independently under the Apache v2 license. After this component is
// rewritten, the entire component will be released under the Apache v2 license.

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

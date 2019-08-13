// Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.
//
// Copyright 2019 Cartesi Pte. Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.



/// @title Subleq machine contract
pragma solidity ^0.5.0;

import "./MachineInterface.sol";
import "./MMInterface.sol";


contract Hasher is MachineInterface {

    event StepGiven(uint8 exitCode);
    event Debug(bytes32 message, uint64 word);

    address mmAddress;

    constructor(address _mmAddress) public {
        mmAddress = _mmAddress;
    }

    /// @notice Performs one step of the hasher machine on memory
    /// @return false indicates a halted machine or invalid instruction
    function step(uint256 _mmIndex) public returns (uint8) {
        // hasher machine simply adds to the memory initial hash :)
        MMInterface mm = MMInterface(mmAddress);
        uint64 valuePosition = 0x0000000000000000;
        uint64 value = uint64(mm.read(_mmIndex, valuePosition));
        require(value < 0xFFFFFFFFFFFFFFFF, "Overflowing machine");
        mm.write(_mmIndex, valuePosition, bytes8(value + 1));
        return(endStep(_mmIndex, 0));
    }

    function getAddress() public view returns (address) {
        return address(this);
    }

    function getMemoryInteractor() public view returns (address) {
        return(address(this));
    }

    function endStep(uint256 _mmIndex, uint8 _exitCode) internal returns (uint8) {
        MMInterface mm = MMInterface(mmAddress);
        mm.finishReplayPhase(_mmIndex);
        emit StepGiven(_exitCode);
        return _exitCode;
    }
}

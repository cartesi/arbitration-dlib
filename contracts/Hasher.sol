// Copyright (C) 2020 Cartesi Pte. Ltd.

// SPDX-License-Identifier: GPL-3.0-only
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


/// @title Subleq machine contract
pragma solidity ^0.7.0;

import "./MachineInterface.sol";
import "./MMInterface.sol";


contract Hasher is MachineInterface {

    event Debug(bytes32 message, uint64 word);

    address mmAddress;

    constructor(address _mmAddress) {
        mmAddress = _mmAddress;
    }

    /// @notice Performs one step of the hasher machine on memory
    /// @return false indicates a halted machine or invalid instruction
    function step(uint256 _mmIndex) public override returns (uint8) {
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

    function getMemoryInteractor() public override view returns (address) {
        return(address(this));
    }

    function endStep(uint256 _mmIndex, uint8 _exitCode) internal returns (uint8) {
        MMInterface mm = MMInterface(mmAddress);
        mm.finishReplayPhase(_mmIndex);
        emit StepGiven(_exitCode);
        return _exitCode;
    }
}

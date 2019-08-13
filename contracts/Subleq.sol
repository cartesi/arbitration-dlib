// Arbritration DLib is the combination of the on-chain protocol and off-chain
// protocol that work together to resolve any disputes that might occur during the
// execution of a Cartesi DApp.

// Copyright (C) 2019 Cartesi Pte. Ltd.

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
pragma solidity ^0.5.0;

import "./MachineInterface.sol";
import "./MMInterface.sol";


contract Subleq is MachineInterface {

    event StepGiven(uint8 exitCode);
    event Debug(bytes32 message, uint64 word);

    address mmAddress;

    // use storage because of solidity's problem with locals ("Stack too deep")
    uint64 pcPosition;
    uint64 icPosition;
    uint64 ocPosition;
    uint64 hsPosition;
    uint64 rSizePosition;
    uint64 iSizePosition;
    uint64 oSizePosition;
    uint64 pc;    // program counter
    uint64 ic;    // input counter
    uint64 oc;    // output counter
    uint64 hs;    // halt state flag
    uint64 rSize; // max size of ram
    uint64 iSize; // max size of input
    uint64 oSize; // max size of output
    int64 memAddrA;
    int64 memAddrB;
    int64 memAddrC;
    uint64 ramSize;
    uint64 inputMaxSize;
    uint64 outputMaxSize;

    constructor(address _mmAddress) public {
        mmAddress = _mmAddress;
    }

    /// @notice Performs one step of the subleq machine on memory
    /// @return false indicates a halted machine or invalid instruction
    function step(uint256 _mmIndex) public returns (uint8) {
        // Architecture
        // +----------------+----------------+----------------+----------------+
        // | ram            | pc ic oc hs    | input          | output         |
        // |                | rs is os       |                |                |
        // +----------------+----------------+----------------+----------------+
        // Exit codes:
        // 0  - Success
        // 1  - Halted machine
        // 2  - Operator A should be -1, 0 or positive
        // 3  - Operator B should be -1, 0 or positive
        // 4  - Operators A and B cannot be both -1
        // 5  - Out of memory (addressed by operator A)
        // 6  - Out of memory (addressed by operator B)
        // 7  - Out of memory (addressed by operator C)
        // 8  - Overflow of maximum input size
        // 9  - Overflow of maximum output size
        // 10 -
        // 11 -
        // 12 -
        // 13 -
        MMInterface mm = MMInterface(mmAddress);
        pcPosition = 0x4000000000000000;
        icPosition = 0x4000000000000008;
        ocPosition = 0x4000000000000010;
        hsPosition = 0x4000000000000018;
        rSizePosition = 0x4000000000000020;
        iSizePosition = 0x4000000000000028;
        oSizePosition = 0x4000000000000030;

        pc = uint64(mm.read(_mmIndex, pcPosition));
        ic = uint64(mm.read(_mmIndex, icPosition));
        oc = uint64(mm.read(_mmIndex, ocPosition));
        hs = uint64(mm.read(_mmIndex, hsPosition));

        rSize = uint64(mm.read(_mmIndex, rSizePosition));
        iSize = uint64(mm.read(_mmIndex, iSizePosition));
        oSize = uint64(mm.read(_mmIndex, oSizePosition));
        memAddrA = int64(mm.read(_mmIndex, pc));
        memAddrB = int64(mm.read(_mmIndex, pc + 8));
        memAddrC = int64(mm.read(_mmIndex, pc + 16));

        // require the sizes of ram, input and output to be reasonable
        require(rSize < 0x0000ffffffffffff, "rSize bad value");
        require(iSize < 0x0000ffffffffffff, "iSize bad value");
        require(oSize < 0x0000ffffffffffff, "oSize bad value");

        // if first or second operator are < -1, throw
        if (hs != 0x0000000000000000) {
            return(endStep(_mmIndex, 1));
        }
        if (memAddrA < -1) {
            return(endStep(_mmIndex, 2));
        }
        if (memAddrB < -1) {
            return(endStep(_mmIndex, 3));
        }
        if (memAddrA == -1 && memAddrB == -1) {
            return(endStep(_mmIndex, 4));
        }
        if (memAddrA >= 0 && uint64(memAddrA) > rSize) {
            return(endStep(_mmIndex, 5));
        }
        if (memAddrB >= 0 && uint64(memAddrB) > rSize) {
            return(endStep(_mmIndex, 6));
        }
        // if first operator is -1, read from input

        //emit Debug("memAddrA", uint64(memAddrA));

        if (memAddrA == -1) {
            // test if input is out of range
            if (ic - 0x8000000000000000 > iSize) {
                return(endStep(_mmIndex, 8));
            }
            // read input at ic
            uint64 loaded = uint64(mm.read(_mmIndex, ic));
            mm.write(_mmIndex, uint64(memAddrB) * 8, bytes8(loaded));
            // increment ic
            mm.write(_mmIndex, icPosition, bytes8(ic + 8));
            // increment pc by three words
            mm.write(_mmIndex, pcPosition, bytes8(pc + 24));
            return(endStep(_mmIndex, 0));
        }
        // if first operator is non-negative, load the memory address
        uint64 valueA = uint64(mm.read(_mmIndex, uint64(memAddrA) * 8));
        // if first operator is non-negative, but second operator is -1,
        // write to output
        if (memAddrB == -1) {
        // test if output is out of range
            if (oc - 0xc000000000000000 > oSize) {
                return(endStep(_mmIndex, 9));
            }
            // write contents addressed by first operator into output
            mm.write(_mmIndex, oc, bytes8(valueA));
            // increment oc
            mm.write(_mmIndex, ocPosition, bytes8(oc + 8));
            // increment pc by three words
            mm.write(_mmIndex, pcPosition, bytes8(pc + 24));
            // cancelling this rule of halting on negative write
            // if (int64(valueA) < 0) { memoryManager.write(hsPosition, 1); }
            return(endStep(_mmIndex, 0));
        }
        // if valueB is non-negative, make the subleq operation
        uint64 valueB = uint64(mm.read(_mmIndex, uint64(memAddrB) * 8));
        uint64 subtraction = uint64(int64(valueB) - int64(valueA));
        // write subtraction to memory addressed by second operator
        mm.write(_mmIndex, uint64(memAddrB) * 8, bytes8(subtraction));
        if (int64(subtraction) <= 0) {
            if (uint64(memAddrC) > rSize) {
                return(endStep(_mmIndex, 7));
            }
            if (memAddrC < 0) {
                // halt machine
                mm.write(_mmIndex, hsPosition, bytes8(uint64(1)));
                return(endStep(_mmIndex, 0));
            }
            mm.write(_mmIndex, pcPosition, bytes8(memAddrC * 8));
            return(endStep(_mmIndex, 0));
        }
        mm.write(_mmIndex, pcPosition, bytes8(pc + 24));
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

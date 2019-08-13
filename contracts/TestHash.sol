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


pragma solidity ^0.5.0;


contract TestHash {

    event OutB32(bytes32 _out);
    event OutUint64(uint64 _out);

    function testing(bytes8, uint64) public {

        uint64 a = uint64(0x0000000000000001);
        uint64 b = uint64(0x0100000000000000);

        emit OutB32(keccak256(abi.encodePacked(a)));
        emit OutB32(keccak256(abi.encodePacked(b)));
        emit OutB32(keccak256(abi.encodePacked(a, b)));
        emit OutB32(keccak256(abi.encodePacked(a + b)));
    }
}

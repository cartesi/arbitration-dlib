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


/// @title Library for Merkle proofs
pragma solidity ^0.5.0;


library Merkle {
    function getRoot(uint64 _position, bytes8 _value, bytes32[] memory proof) internal pure returns (bytes32) {
        require((_position & 7) == 0, "Position is not aligned");
        require(proof.length == 61, "Proof length does not match");
        bytes32 runningHash = keccak256(abi.encodePacked(_value));
        // iterate the hash with the uncle subtree provided in proof
        uint64 eight = 8;
        for (uint i = 0; i < 61; i++) {
            if ((_position & (eight << i)) == 0) {
                runningHash = keccak256(abi.encodePacked(runningHash, proof[i]));
            } else {
                runningHash = keccak256(abi.encodePacked(proof[i], runningHash));
            }
        }
        return (runningHash);
    }
}

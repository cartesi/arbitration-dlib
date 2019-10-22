// Arbitration DLib is the combination of the on-chain protocol and off-chain
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
        bytes32 runningHash = keccak256(abi.encodePacked(_value));

        return getRootWithDrive(_position, 3, runningHash, proof);
    }

    function getRootWithDrive(
        uint64 _position,
        uint64 _logOfSize,
        bytes32 _drive,
        bytes32[] memory siblings
    ) internal pure returns (bytes32) {
        require(_logOfSize >= 3, "Must be at least a word");
        require(_logOfSize <= 64, "Cannot be bigger than the machine itself");

        uint64 size = 2 ** _logOfSize;

        require(((size - 1) & _position) == 0, "Position is not aligned");
        require(siblings.length == 64 - _logOfSize, "Proof length does not match");

        for (uint i = 0; i < siblings.length; i++) {
            if ((_position & (size << i)) == 0) {
                _drive = keccak256(abi.encodePacked(_drive, siblings[i]));
            } else {
                _drive = keccak256(abi.encodePacked(siblings[i], _drive));
            }
        }

        return _drive;
    }
}

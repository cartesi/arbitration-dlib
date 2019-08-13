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


/// @title Partition contract
pragma solidity ^0.5.0;

import "./MMInterface.sol";

contract SimpleMemoryInstantiator is MMInterface {
  uint256 private currentIndex = 0;

  struct SimpleMemoryCtx {
    mapping(uint64 => bytes8) value; // value present at address
  }

  mapping(uint256 => SimpleMemoryCtx) private instance;

  function instantiate(address, address, bytes32) public returns (uint256)
  {
    active[currentIndex] = true;
    return(currentIndex++);
  }

  /// @notice reads a slot in memory
  /// @param _address of the desired memory
  function read(uint256 _index, uint64 _address) public
    returns (bytes8)
  {
    require((_address & 7) == 0);
    return instance[_index].value[_address];
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param _address of the write
  /// @param _value to be written
  function write(uint256 _index, uint64 _address, bytes8 _value) public
  {
    require((_address & 7) == 0);
    instance[_index].value[_address] = _value;
  }

  function newHash(uint256) public view returns (bytes32)
  { require(false); }

  function finishProofPhase(uint256) public {}

  function finishReplayPhase(uint256) public {}

  function stateIsWaitingProofs(uint256) public view returns (bool)
  { require(false);
    return(true);
  }

  function stateIsWaitingReplay(uint256) public view returns (bool)
  {
    require(false);
    return(true);
  }

  function stateIsFinishedReplay(uint256) public view returns (bool)
  {
    require(false);
    return(true);
  }

  function isConcerned(uint256, address) public view returns (bool)
  {
    return(true);
  }

  function getCurrentState(uint256) public view
    returns (bytes32)
  {
    return(bytes32(0));
  }

  function getSubInstances(uint256)
    public view returns (address[] memory _addresses,
                        uint256[] memory _indices)
  {
    address[] memory a = new address[](0);
    uint256[] memory b = new uint256[](0);
    return(a, b);
  }

}

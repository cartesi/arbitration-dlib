// Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.
//
// Copyright 2019 Cartesi Pte. Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.



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

// Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.
//
// Copyright 2019 Cartesi Pte. Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.



/// @title Interface for memory manager instantiator
pragma solidity ^0.5.0;


contract Instantiator {
    uint256 public currentIndex = 0;

    mapping(uint256 => bool) internal active;
    mapping(uint256 => uint256) internal nonce;

    modifier onlyInstantiated(uint256 _index) {
        require(currentIndex > _index, "Index not instantiated");
        _;
    }

    modifier onlyActive(uint256 _index) {
        require(currentIndex > _index, "Index not instantiated");
        require(isActive(_index), "Index inactive");
        _;
    }

    modifier increasesNonce(uint256 _index)
    {
        nonce[_index]++;
        _;
    }

    function isActive(uint256 _index) public view returns (bool) {
        return(active[_index]);
    }

    function getNonce(uint256 _index) public view
        onlyActive(_index)
        returns (uint256 currentNonce)
    {
        return nonce[_index];
    }

    function isConcerned(uint256 _index, address _user) public view returns (bool);

    function getSubInstances(uint256 _index) public view returns (address[] memory _addresses, uint256[] memory _indices);

    function deactivate(uint256 _index) internal {
        active[_index] = false;
        nonce[_index] = 0;
    }
}

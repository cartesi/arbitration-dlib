// Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.
//
// Copyright 2019 Cartesi Pte. Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.



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

// Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.
//
// Copyright 2019 Cartesi Pte. Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.



/// @title Interface for compute instantiator
pragma solidity ^0.5.0;

import "./Instantiator.sol";


contract ComputeInterface is Instantiator {
    enum state {
        WaitingClaim,
        WaitingConfirmation,
        ClaimerMissedDeadline,
        WaitingChallenge,
        ChallengerWon,
        ClaimerWon,
        ConsensusResult
    }
    function getCurrentState(uint256 _index) public view returns (bytes32);

    function instantiate(
        address _challenger,
        address _claimer,
        uint256 _roundDuration,
        address _machineAddress,
        bytes32 _initialHash,
        uint256 _finalTime) public returns (uint256);

    function submitClaim(uint256 _index, bytes32 _claimedFinalHash) public;
    function confirm(uint256 _index) public;
    function challenge(uint256 _index) public;
    function winByVG(uint256 _index) public;
    function claimVictoryByTime(uint256 _index) public;
    function isConcerned(uint256 _index, address _user) public view returns (bool);
}

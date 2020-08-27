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

/// @title Interface for compute instantiator
pragma solidity ^0.7.0;

import "@cartesi/util/contracts/Instantiator.sol";

interface ComputeInterface is Instantiator {
    enum state {
        WaitingClaim,
        WaitingConfirmation,
        ClaimerMissedDeadline,
        WaitingChallenge,
        ChallengerWon,
        ClaimerWon,
        ConsensusResult
    }

    function getCurrentState(uint256 _index) external view returns (bytes32);

    function instantiate(
        address _challenger,
        address _claimer,
        uint256 _roundDuration,
        address _machineAddress,
        bytes32 _initialHash,
        uint256 _finalTime
    ) external returns (uint256);

    function submitClaim(uint256 _index, bytes32 _claimedFinalHash) external;

    function confirm(uint256 _index) external;

    function challenge(uint256 _index) external;

    function winByVG(uint256 _index) external;

    function claimVictoryByTime(uint256 _index) external;
}

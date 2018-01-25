/// @title Partition contract
pragma solidity ^0.4.18;

contract mortal {
  address public owner;

  function mortal() public {
    owner = msg.sender;
  }

  function kill() public {
    if (msg.sender == owner) selfdestruct(owner);
  }
}


contract depth is mortal {
  bytes32 constant public zeros =
    0x0000000000000000000000000000000000000000000000000000000000000000;

  address public challenger;
  address public claimer;

  uint public timeOfLastMove;
  uint public roundDuration;

  bytes32 public claimerCurrentHash;
  bytes32 public claimerLeftChildHash;
  bytes32 public claimerRightChildHash;
  uint8 public currentDepth;
  uint64 public currentAddress;

  bytes32 public controversialHashOfClaimer;

  enum state { WaitingQuery, WaitingHashes,
               ChallengerWon, ClaimerWon,
               WaitingControversialHash,
               ControversialHashFound}
  state public currentState;

  event QueryPosted(uint8 theCurrentDepth, uint64 theCurrentAddress);
  event HashesPosted(bytes32 theLeftHash, bytes32 theRightHash);
  event ChallengeEnded(state theState);
  event ControversialHashPosted(uint64 addressStartingDivergence,
                                bytes32 theControversialHashOfClaimer);

  //            Hashes (children of 0 at at level 1)
  //              |
  //             ...
  //              |
  //            Hashes (children of 58 at level 59)
  //              |
  //            Query
  //              |
  //            ContHash
  //              |
  //            ContFound

  function depth(address theChallenger, address theClaimer,
                 bytes32 theClaimerHashOfRoot,
                 uint theRoundDuration) public
  {
    require(theChallenger != theClaimer);
    challenger = theChallenger;
    claimer = theClaimer;
    claimerCurrentHash = theClaimerHashOfRoot;
    currentDepth = 0;
    currentAddress = 0;
    roundDuration = theRoundDuration;
    timeOfLastMove = now;
    currentState = state.WaitingHashes;
    QueryPosted(currentDepth, currentAddress);
  }

  /// @notice Answer the query (only claimer can call it).
  /// @param leftHash the hash to the left of the current one.
  /// @param rightHash the hash to the right of the current one.
  function replyQuery(bytes32 leftHash, bytes32 rightHash) public {
    require(msg.sender == claimer);
    require(currentState == state.WaitingHashes);
    require(keccak256(leftHash, rightHash) == claimerCurrentHash);
    claimerLeftChildHash = leftHash;
    claimerRightChildHash = leftHash;
    timeOfLastMove = now;
    currentState = state.WaitingQuery;
    HashesPosted(leftHash, rightHash);
  }

  /// @notice Makes a query (only challenger can call it).
  /// @param continueToTheLeft a boolean saying if we should continue to the
  /// left (otherwise we continue to the right)
  function makeQuery(bool continueToTheLeft) public {
    require(msg.sender == challenger);
    require(currentState == state.WaitingQuery);
    if(continueToTheLeft) {
      claimerCurrentHash = claimerLeftChildHash;
    } else {
      claimerCurrentHash = claimerRightChildHash;
      currentAddress = currentAddress + uint64(2)**uint64(63 - currentDepth);
    }
    currentDepth = currentDepth + 1;
    if (currentDepth == 59) {
      currentState = state.WaitingControversialHash;
    } else {
      currentState = state.WaitingHashes;
    }
    timeOfLastMove = now;
    QueryPosted(currentDepth, currentAddress);
  }

  /// @notice Post hash that was found different between claimer and challenger
  /// @param word1 first word composing hash
  /// @param word2 second word composing hash
  /// @param word3 third word composing hash
  /// @param word4 forth word composing hash
  function postControversialHash(bytes8 word1, bytes8 word2,
                                 bytes8 word3, bytes8 word4) public {
    require(msg.sender == claimer);
    require(currentState == state.WaitingControversialHash);
    require(currentDepth == 59);
    bytes32 word1Hash = keccak256(word1);
    bytes32 word2Hash = keccak256(word2);
    bytes32 word3Hash = keccak256(word3);
    bytes32 word4Hash = keccak256(word4);
    bytes32 word12Hash = keccak256(word1Hash, word2Hash);
    bytes32 word34Hash = keccak256(word3Hash, word4Hash);
    require(keccak256(word12Hash, word34Hash) == claimerCurrentHash);
    controversialHashOfClaimer = zeros;
    controversialHashOfClaimer |= bytes32(word1) << 192;
    controversialHashOfClaimer |= bytes32(word2) << 128;
    controversialHashOfClaimer |= bytes32(word3) << 64;
    controversialHashOfClaimer |= bytes32(word4);
    currentState = state.ControversialHashFound;
    ControversialHashPosted(currentAddress, controversialHashOfClaimer);
    ChallengeEnded(currentState);
  }

  /// @notice Claim victory for opponent timeout.
  function claimVictoryByTime() public {
    if ((msg.sender == claimer) && (currentState == state.WaitingQuery)
        && (now > timeOfLastMove + roundDuration)) {
      currentState = state.ClaimerWon;
      ChallengeEnded(currentState);
    }
    if ((msg.sender == challenger) && (currentState == state.WaitingHashes)
        && (now > timeOfLastMove + roundDuration)) {
      currentState = state.ChallengerWon;
      ChallengeEnded(currentState);
    }
    if ((msg.sender == challenger)
        && (currentState == state.WaitingControversialHash)
        && (now > timeOfLastMove + roundDuration)) {
      currentState = state.ChallengerWon;
      ChallengeEnded(currentState);
    }
  }
}


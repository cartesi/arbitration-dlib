/// @title Depth library contract
pragma solidity 0.4.24;

library DepthLib {

  enum state { WaitingQuery, WaitingHashes,
               ChallengerWon, ClaimerWon,
               WaitingControversialPhrase,
               ControversialPhraseFound }

  struct DepthCtx {
    address challenger;
    address claimer;

    uint timeOfLastMove;
    uint roundDuration;

    bytes32 claimerCurrentHash;
    bytes32 claimerLeftChildHash;
    bytes32 claimerRightChildHash;
    uint8 currentDepth;
    uint64 currentAddress;

    bytes32 controversialPhraseOfClaimer;
    state currentState;
  }

  event QueryPosted(uint8 _currentDepth, uint64 _currentAddress);
  event HashesPosted(bytes32 _leftHash, bytes32 _rightHash);
  event ChallengeEnded(uint8 _state);
  event ControversialPhrasePosted(uint64 addressStartingDivergence,
                                  bytes32 _controversialPhraseOfClaimer);

  // Suppose two agents have distinct memory states, of course with different
  // Merkel-tree hashes. This contract helps them find the exact point where
  // their contents diverge. Instead of looking for a diverging byte or a
  // diverging 64 bit word, we decided to return a "phrase" which is a 256 bit
  // aligned sequence (four adjacent words aligned with 256 bits). This can
  // be useful if the memory contained a list of 256 bit hashes.
  //
  // These are the states of the machine:
  //
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

  function init(DepthCtx storage self, address _challenger,
                address _claimer, bytes32 _claimerHashOfRoot,
                uint _roundDuration) public
  {
    require(_challenger != _claimer);
    self.challenger = _challenger;
    self.claimer = _claimer;
    self.claimerCurrentHash = _claimerHashOfRoot;
    self.currentDepth = 0;
    self.currentAddress = 0;
    self.roundDuration = _roundDuration;
    self.timeOfLastMove = now;
    self.currentState = state.WaitingHashes;
    emit QueryPosted(self.currentDepth, self.currentAddress);
  }

  /// @notice Answer the query (only claimer can call it) by posting.
  /// two hashes that combine to the currentHash.
  /// @param leftHash the child hash to the left of the current one.
  /// @param rightHash the child hash to the right of the current one.
  function replyQuery(DepthCtx storage self, bytes32 leftHash,
                      bytes32 rightHash) public
  {
    require(msg.sender == self.claimer);
    require(self.currentState == state.WaitingHashes);
    require(keccak256(leftHash, rightHash) == self.claimerCurrentHash);
    self.claimerLeftChildHash = leftHash;
    self.claimerRightChildHash = rightHash;
    self.timeOfLastMove = now;
    self.currentState = state.WaitingQuery;
    emit HashesPosted(leftHash, rightHash);
    //HashesPosted(keccak256(leftHash, rightHash), claimerCurrentHash);
  }

  /// @notice Makes a query (only challenger can call it) indicating the
  /// direction to continue the search.
  /// @param continueToTheLeft a boolean saying if we should continue to the
  /// left (otherwise we continue to the right)
  function makeQuery(DepthCtx storage self, bool continueToTheLeft,
                     bytes32 differentHash) public
  {
    require(msg.sender == self.challenger);
    require(self.currentState == state.WaitingQuery);
    if(continueToTheLeft) {
      self.claimerCurrentHash = self.claimerLeftChildHash;
    } else {
      self.claimerCurrentHash = self.claimerRightChildHash;
      self.currentAddress = self.currentAddress
        + uint64(2)**uint64(63 - self.currentDepth);
    }
    // test if challenger knows the new problematic hash
    require(self.claimerCurrentHash == differentHash);
    self.currentDepth = self.currentDepth + 1;
    if (self.currentDepth == 59) {
      self.currentState = state.WaitingControversialPhrase;
    } else {
      self.currentState = state.WaitingHashes;
    }
    self.timeOfLastMove = now;
    emit QueryPosted(self.currentDepth, self.currentAddress);
  }

  /// @notice Post hash that was found different between claimer and challenger
  /// @param word1 first word composing hash
  /// @param word2 second word composing hash
  /// @param word3 third word composing hash
  /// @param word4 forth word composing hash
  function postControversialPhrase(DepthCtx storage self, bytes8 word1,
                                   bytes8 word2, bytes8 word3,
                                   bytes8 word4) public
  {
    require(msg.sender == self.claimer);
    require(self.currentState == state.WaitingControversialPhrase);
    require(self.currentDepth == 59);
    bytes32 word1Hash = keccak256(word1);
    bytes32 word2Hash = keccak256(word2);
    bytes32 word3Hash = keccak256(word3);
    bytes32 word4Hash = keccak256(word4);
    bytes32 word12Hash = keccak256(word1Hash, word2Hash);
    bytes32 word34Hash = keccak256(word3Hash, word4Hash);
    require(keccak256(word12Hash, word34Hash) == self.claimerCurrentHash);
    self.controversialPhraseOfClaimer = bytes32(word1);
    self.controversialPhraseOfClaimer |= bytes32(word2) >> 64;
    self.controversialPhraseOfClaimer |= bytes32(word3) >> 128;
    self.controversialPhraseOfClaimer |= bytes32(word4) >> 192;
    self.currentState = state.ControversialPhraseFound;
    emit ControversialPhrasePosted(self.currentAddress,
                                   self.controversialPhraseOfClaimer);
    emit ChallengeEnded(uint8(self.currentState));
  }

  /// @notice Claim victory for opponent timeout.
  function claimVictoryByTime(DepthCtx storage self) public {
    if ((msg.sender == self.claimer)
        && (self.currentState == state.WaitingQuery)
        && (now > self.timeOfLastMove + self.roundDuration)) {
      self.currentState = state.ClaimerWon;
      emit ChallengeEnded(uint8(self.currentState));
      return;
    }
    if ((msg.sender == self.challenger)
        && (self.currentState == state.WaitingHashes)
        && (now > self.timeOfLastMove + self.roundDuration)) {
      self.currentState = state.ChallengerWon;
      emit ChallengeEnded(uint8(self.currentState));
      return;
    }
    if ((msg.sender == self.challenger)
        && (self.currentState == state.WaitingControversialPhrase)
        && (now > self.timeOfLastMove + self.roundDuration)) {
      self.currentState = state.ChallengerWon;
      emit ChallengeEnded(uint8(self.currentState));
      return;
    }
    require(false);
  }
}


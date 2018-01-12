// This is not the best way to do a bet between two players.
// For better bets, use something similar to RANDAO's algorithm.
// This should however be safe and more modular for other tasks.

/// @title Betting contract
pragma solidity ^0.4.0;

import "./partition.sol";
import "./lib/bokkypoobah/Token.sol";

contract hireCPU {
  Token public tokenContract; // address of Themis ERC20 contract

  address public client; // who is hiring the provider to perform a calculation
  address public provider; // winner of bit to preform calculation

  bytes32 public initialHash;
  bytes public initialURI;
  uint public finalTime;
  bytes8 public addressForSeed;
  uint64 public initialSeed;
  uint64 public numberOfSeeds;

  uint public maxPriceOffered; // maximum price offered for the computation
  uint public depositRequired; // deposit necessary in order to participate

  address public lowestBidder;
  uint public lowestBid;
  uint public secondLowestBid;

  uint public timeOfLastMove; // last time someone made a move with deadline
  uint public auctionDuration; // time dedicated for auction
  uint public roundDuration; // time interval one has before expiration
  uint public jobDuration; // time to perform the job

  bytes32 claimedHashOfEncryptedOutput;
  bytes32 acknowledgedKey;

  partition public partitionContract;

  enum state { WaitingBids, WaitingSolution, WaitingTransferReceipt,
               WaitingAcknowledgedKey, WaitingAcknowledgedApproval,
               WaitingUnacknowledgedKey,
               Finished }

  state public currentState;

  event AnounceJob(address theClient, uint theFinalTime, bytes32 theInitialHash,
                   bytes theInitialURI,
                   bytes8 theAddressForSeed, uint64 theInitialSeed,
                   uint64 theNumberOfSeeds, uint theMaxPriceOffered,
                   uint theDepositRequired, uint theAuctionDuraiton,
                   uint theRoundDuration, uint theJobDuration);
  event LowestBidDecreased(address bidder, uint amount);
  event SolutionPosted(bytes32 theClaimedHashOfEncryptedOutput);
  //event ChallengePosted(address thePartitionContract);
  //event WinerFound(state finalState);

  function hireCPU(address theClient, uint theFinalTime, bytes32 theInitialHash,
                   bytes theInitialURI,
                   bytes8 theAddressForSeed, uint64 theInitialSeed,
                   uint64 theNumberOfSeeds, uint theMaxPriceOffered,
                   uint theDepositRequired, uint theAuctionDuration,
                   uint theRoundDuration, uint theJobDuration)
    payable public {

    tokenContract = Token(0xe78A0F7E598Cc8b0Bb87894B0F60dD2a88d6a8Ab);
    client = theClient;

    initialHash = theInitialHash;
    initialURI = theInitialURI;

    require(theFinalTime > 0);
    finalTime = theFinalTime;

    addressForSeed = theAddressForSeed;
    initialSeed = theInitialSeed;
    numberOfSeeds = theNumberOfSeeds;

    maxPriceOffered = theMaxPriceOffered;
    lowestBid = theMaxPriceOffered;
    depositRequired = theDepositRequired;
    tokenContract.transferFrom(msg.sender, address(this), theMaxPriceOffered);

    auctionDuration = theAuctionDuration;
    roundDuration = theRoundDuration;
    jobDuration = theJobDuration;
    timeOfLastMove = now;

    currentState = state.WaitingBids;
    AnounceJob(client, finalTime, initialHash, initialURI,
               addressForSeed, initialSeed, numberOfSeeds, maxPriceOffered,
               depositRequired, auctionDuration, roundDuration,
               jobDuration);
  }

  function getPartitionCurrentState() view public returns (partition.state) {
    return partitionContract.currentState();
  }

  /// @notice Posts a bid for the announced job
  /// @param numberOfTokens required by bidder to perform the computation
  function bid(uint numberOfTokens) public {
    require(currentState == state.WaitingBids);
    require(numberOfTokens < lowestBid);
    tokenContract.transferFrom(msg.sender, address(this), depositRequired);
    lowestBidder = msg.sender;
    lowestBid = numberOfTokens;
    LowestBidDecreased(msg.sender, numberOfTokens);
  }

  function finishAuctionPhase() public {
    require(currentState == state.WaitingBids);
    require(now > timeOfLastMove + auctionDuration);
    provider = lowestBidder;
    timeOfLastMove = now;
    currentState = state.WaitingSolution;
  }

  function postSolution(bytes32 theClaimedHashOfEncryptedOutput) public {
    require(msg.sender == provider);
    require(currentState == state.WaitingSolution);
    claimedHashOfEncryptedOutput = theClaimedHashOfEncryptedOutput;
    currentState = state.WaitingTransferReceipt;
    timeOfLastMove = now;
    SolutionPosted(claimedHashOfEncryptedOutput);
  }

  // this part of the code refers to an acknowledged transfer of data
  function acknowledgeTransfer() public {
    require(msg.sender == client);
    require(currentState == state.WaitingTransferReceipt);
    timeOfLastMove = now;
    currentState = state.WaitingAcknowledgedKey;
  }

  function sendAcknowledgedKey(bytes32 theAcknowledgedKey) public {
    require(msg.sender == provider);
    require(currentState == state.WaitingAcknowledgedKey);
    timeOfLastMove = now;
    acknowledgedKey = theAcknowledgedKey;
    currentState = state.WaitingAcknowledgedApproval;
  }

  function aproveAcknowledgedCalculation() public {
    require(msg.sender == client);
    require(currentState == state.WaitingAcknowledgedApproval);
    timeOfLastMove = now;
    tokenContract.transfer(provider, depositRequired + lowestBid);
    currentState = state.Finished;
  }

  // here we have an acknowledged transfer but a disagreement in calculation value



  // this part of the code refers to a disagreement on the transfer of data





  // to kill the contract and receive refunds
  function killContract() public {
    require(currentState == state.Finished);
    uint balance = tokenContract.balanceOf(address(this));
    tokenContract.transfer(client, balance);
    selfdestruct(client);
  }

  /*
  /// @notice Post a challenge to claimed final hash (only challenger can do)
  function postChallenge() public payable {
    require(msg.sender == challenger);
    require(currentState == state.WaitingChallenge);
    //require(msg.value > challengeCost);
    // one needs to pay to post a challenge
    partitionContract = new partition(challenger, claimer,
                                      initialHash, claimedFinalHash,
                                      finalTime, 10, roundDuration);
    currentState = state.WaitingResolution;
    ChallengePosted(partitionContract);
  }

  /// @notice Claim victory (challenger only)
  function challengerClaimVictory() public {
    require(msg.sender == challenger);
    bool won = false;
    // claimer lost deadline to submit claim
    if (currentState == state.WaitingClaim
        && now > timeOfLastMove + roundDuration) {
      won = true;
    }
    // the claimed number is even (challenger's luck)
    if (currentState == state.WaitingChallenge
        && uint(claimedFinalHash) % 2 == 0) {
      won = true;
    }
    // challenger won the partition challenge (claimer misses deadline there)
    if (currentState == state.WaitingResolution
        && getPartitionCurrentState() == partition.state.ChallengerWon) {
      won = true;
    }
    // partition challenge ended in divergence and challenger won divergence
    if (currentState == state.WaitingResolution
        && getPartitionCurrentState() == partition.state.DivergenceFound) {
      bytes32 beforeDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime());
      bytes32 afterDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime() + 1);
      if (keccak256(beforeDivergence) != afterDivergence) {
        won = true;
      }
    }
    if (won) {
      currentState = state.ChallengerWon;
      WinerFound(currentState);
      selfdestruct(challenger);
    }
  }

  /// @notice Claim victory (claimer only)
  function claimerClaimVictory() public {
    require(msg.sender == claimer);
    bool won = false;
    // timeout to submit challenge
    if (currentState == state.WaitingChallenge
        && now > timeOfLastMove + roundDuration) {
      won = true;
    }
    // claimer won the partition challenge
    if (currentState == state.WaitingResolution
        && getPartitionCurrentState() == partition.state.ClaimerWon) {
      won = true;
    }
    // partition challenge ended in divergence and claimer won divergence
    if (currentState == state.WaitingResolution
        && getPartitionCurrentState() == partition.state.DivergenceFound) {
      bytes32 beforeDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime());
      bytes32 afterDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime() + 1);
      if (keccak256(beforeDivergence) == afterDivergence) {
        won = true;
      }
    }
    if (won) {
      currentState = state.ClaimerWon;
      WinerFound(currentState);
      selfdestruct(claimer);
    }
  }
  */
}


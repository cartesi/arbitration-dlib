// This is not the best way to do a bet between two players.
// For better bets, use something similar to RANDAO's algorithm.
// This should however be safe and more modular for other tasks.

/// @title Betting contract
pragma solidity ^0.4.0;

import "./mm.sol";
import "./subleq.sol";
import "./partition.sol";
import "./lib/bokkypoobah/Token.sol";

contract hireCPU {
  bytes32 constant public zeros =
    0x0000000000000000000000000000000000000000000000000000000000000000;

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

  bytes32 public claimedHashOfEncryptedOutputList;
  bytes32 public acknowledgedKey;

  // for disputes only
  uint64 public divergingSeed;
  bytes32 public decryptionMachinePreparationHash; // hash of machine before key
  bytes32 public decryptionMachineInitialHash; // hash of machine after key
  bytes32 public decryptionMachineFinalHash; // hash of machine after running

  bytes32 public clientMachinePreparationHash; // hash of machine before seed
  bytes32 public clientMachineInitialHash; // hash of machine after seed
  bytes32 public clientMachineFinalHash; // hash of machine after running

  bytes32 public hashOfEncryptedSelectedOuput;

  // for challenges
  address challenger;
  address claimer;
 
  // for memory read/write and machine run challenges
  mm public mmContract;
  function getMMCurrentState() view public returns (mm.state) {
    return mmContract.currentState();
  }
  // for memory challenges, this are the relevant hash and position to be tested
  bytes32 hashForChallenge;
  uint64 memoryPositionForChallenge;

  // for processing challenges
  partition public partitionContract;
  function getPartitionCurrentState() view public returns (partition.state) {
    return partitionContract.currentState();
  }

  subleq public subleqContract;

  // These are the possible (abbreviated) states of the contract,
  // see the full names below:
  //
  //                               Bids
  //                                |
  //                               Sol
  //                                |
  //         -------------------- TrRec -------
  //        /                                  \
  //     AckKey                              UnackKey
  //       |                                    |
  //     AckApp --                             ...
  //       |      \
  //     AckExp    F
  //          \
  //      -- AckChal --
  //     /             \
  // MemChall        PartDisp
  //    |               |
  //    F            MachDisp
  //                    |
  //                    F


  enum state { WaitingBids, WaitingSolution, WaitingTransferReceipt,
               WaitingAcknowledgedKey, WaitingAcknowledgedApproval,
               WaitingAcknowledgedExplanation, WaitingAcknowledgedChallenge,
               WaitingAcknowledgedResponseToClient,
               WaitingPartitionDispute, WaitingMachineStep,

               WaitingUnacknowledgedKey,
               Finished }

  enum challenge { outputHash, keyInsertion, decyptMachineRun,
                   seedInsertion, clientMachineRun }

  state public currentState;

  event AnounceJob(address theClient, uint theFinalTime, bytes32 theInitialHash,
                   bytes theInitialURI,
                   bytes8 theAddressForSeed, uint64 theInitialSeed,
                   uint64 theNumberOfSeeds, uint theMaxPriceOffered,
                   uint theDepositRequired, uint theAuctionDuraiton,
                   uint theRoundDuration, uint theJobDuration);
  event LowestBidDecreased(address bidder, uint amount);
  event SolutionPosted(bytes32 theClaimedHashOfEncryptedOutputList);
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
    require(theInitialSeed + theNumberOfSeeds > theInitialSeed); // sum < 2^64
    // all hashes must fit mm and each hash takes 4 words
    require(theInitialSeed + theNumberOfSeeds < uint64(0x4000000000000000));

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

  function postSolution(bytes32 theClaimedHashOfEncryptedOutputList) public {
    require(msg.sender == provider);
    require(currentState == state.WaitingSolution);
    claimedHashOfEncryptedOutputList = theClaimedHashOfEncryptedOutputList;
    currentState = state.WaitingTransferReceipt;
    timeOfLastMove = now;
    SolutionPosted(claimedHashOfEncryptedOutputList);
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

  // here we have an acknowledged transfer and aggreed in calculation
  function aproveAcknowledgedCalculation() public {
    require(msg.sender == client);
    require(currentState == state.WaitingAcknowledgedApproval);
    timeOfLastMove = now;
    tokenContract.transfer(provider, depositRequired + lowestBid);
    currentState = state.Finished;
  }

  // here we have an acknowledged transfer but a disagreement in calculation
  function disaproveAcknowledgedCalculation(uint64 theDivergingSeed) public {
    require(msg.sender == client);
    require(currentState == state.WaitingAcknowledgedApproval);
    require(theDivergingSeed >= initialSeed);
    require(theDivergingSeed < initialSeed + numberOfSeeds);
    tokenContract.transferFrom(client, address(this), depositRequired);
    divergingSeed = theDivergingSeed;
    timeOfLastMove = now;
    currentState = state.WaitingAcknowledgedExplanation;
  }

  function giveAcknowledgedExplanation
    ( bytes32 theHashOfEncryptedSelectedOutput,
      bytes32 theDecryptionMachineInitialHash,
      bytes32 decryptionMachineFinalHash,
      bytes32 theFinal1HashOfDecryptMachine,
      bytes32 theFinal2HashOfDecryptMachine,
      bytes32 theFinal3HashOfDecryptMachine,
      bytes32 theFinal4HashOfDecryptMachine,
      bytes32 theClientMachineInitialHash,
      bytes32 theFinal1HashOfClientMachine,
      bytes32 theFinal2HashOfClientMachine,
      bytes32 theFinal3HashOfClientMachine
      ) {
    require(msg.sender == provider);
    require(currentState = state.WaitingAcknowledgedExplanation);
    hashOfEncryptedSelectedOutput = theHashOfEncryptedSelectedOutput;
    // assemble decryption machine preparation hash
    // 0x00000... has to be replaced by the merkel hash of 2^62 zeros
    // 0x11111... has to be replaced by our machine hash
    // 0x22222... has to be replaced by our decryption hd hash
    bytes32 machine = keccak256
      ( 0x1111111111111111111111111111111111111111111111111111111111111111,
        0x2222222222222222222222222222222222222222222222222222222222222222
        );
    bytes32 inputOutput = keccak256
      ( hashOfEncryptedSelectedOuput,
        0x0000000000000000000000000000000000000000000000000000000000000000
        );
    decryptionMachinePreparationHash = keccak256(machine, inputOutput);
    // state the decryption machine initial hash
    decryptionMachineInitialHash = theDecryptionMachineInitialHash;
    // assemble decryption machine final hash
    machine = keccak256
      ( theFinal1HashOfDecryptMachine,
        theFinal2HashOfDecryptMachine
        );
    inputOutput = keccak256
      ( theFinal3HashOfDecryptMachine,
        theFinal4HashOfDecryptMachine
        );
    decryptionMachineFinalHash = keccak256(machine, inputOutput);
    // state the client machine initial hash
    clientMachineInitialHash = theClientMachineInitialHash;
    // assemble client machine final hash
    machine = keccak256
      ( theFinal1HashOfClientMachine,
        theFinal2HashOfClientMachine,
        );
    inputOutput = keccak256
      ( theFinal3HashOfClientMachine,
        theFinal4HashOfDecryptMachine
        );
    clientMachineFinalHash = keccak256(machine, inputOutput);
    timeOfLastMove = now;
    currentState = state.WaitingAcknowledgedChallenge;
  }

  function postAcknowledgedChallenge(challenge theChallenge) {
    require(msg.sender == client);
    require(currentState = state.WaitingAcknowledgedChallenge);
    timeOfLastMove = now;
    if (theChallenge == challenge.outputHash) {
      challenger = client;
      claimer = provider;
      hashForChallenge = hashOfEncryptedSelectedOuput;
      mmContract = new mm(provider, address(this),
                          claimedHashOfEncryptedOutputList);
      currentState = state.WaitingMemoryReadHashChallenge;
    }
    if (theChallenge == challenge.keyInsert) {
      challenger = client;
      claimer = provider;
      hashForChallenge = hashOfEncryptedSelectedOuput;
      // replace this by the position of the key in decryption machine memory
      memoryPositionForChallenge = 0x5555555555555555;
      mmContract = new mm(provider, address(this),
                          decryptionMachinePreparationMemory);
      currentState = state.WaitingMemoryWriteHashChallenge;
    }
    if (theChallenge == challenge.decryptMachine) {
      bytes32 finalClient1 = keccak256
        ( final1HashOfClientMachine, final2HashOfClientMachine );
      bytes32 finalClient2 = keccak256
        (  );
      partitionContract = new partition(client, provider,
                                        keccak256(machine, inputOutput),
                                        keccak256(finalClient1, finalClient2),
                                        2**64, 10, roundDuration);
      currentState = state.WaitingPartitionDispute;
    }
  }

  function settleMemoryChallenge() {
    require(msg.sender == claimer);
    require(currentState = state.WaitingMemoryReadHashChallenge);
    require(getMMCurrentState() == mm.state.Reading);
    bytes8 word1 = mm.read(32 * divergingSeed);
    bytes8 word2 = mm.read(32 * divergingSeed + 8);
    bytes8 word3 = mm.read(32 * divergingSeed + 16);
    bytes8 word4 = mm.read(32 * divergingSeed + 24);
    bytes32 word = zeros;
    word |= bytes32(word1);
    word |= bytes32(word2) >> 64;
    word |= bytes32(word3) >> 128;
    word |= bytes32(word4) >> 192;
    require(word = claimedHash);
    tokenContract.transfer(provider, 2 * depositRequired + lowestBid);
    currentState = state.Finished;
  }

  function insertionForWriteMemoryChallenge() {
    require(msg.sender == claimer);
    require(currentState = state.WaitingMemoryReadHashChallenge);
    require(getMMCurrentState() == mm.state.Reading);
    bytes8 word1, word2, word3, word4;
    for (uint i = 0; i < 8; i++) {
      word1[i] = hashForChallenge[i];
    }
    for (uint i = 0; i < 8; i++) {
      word2[i] = hashForChallenge[8 + i];
    }
    for (uint i = 0; i < 8; i++) {
      word3[i] = hashForChallenge[16 + i];
    }
    for (uint i = 0; i < 8; i++) {
      word4[i] = hashForChallenge[24 + i];
    }
    mm.write(memoryPositionForChallenge, word1);
    mm.write(memoryPositionForChallenge + ???, word2 + ???);
    mm.write(memoryPositionForChallenge, word3);
    mm.write(memoryPositionForChallenge, word4);
    currentState = state.???;
  }


  function winByPartitionTimeout() {
    require(currentState == state.WaitingPartitionDispute);
    if (getPartitionCurrentState() == partition.state.ChallengerWon) {
      tokenContract.transfer(partition.challenger,
                             2 * depositRequired + lowestBid);
      currentState = state.Finished;
    }
    if (getPartitionCurrentState() == partition.state.ClaimerWon) {
      tokenContract.transfer(partition.claimer,
                             2 * depositRequired + lowestBid);
      currentState = state.Finished;
    }
    require(false);
  }

  function startMachineDisputeStep() {
    require(currentState == state.WaitingPartitionDispute);
    require(getPartitionCurrentState() == partition.state.DivergenceFound);
    // problem with cyclic addresses
    subleqContract = new subleq(provider, address(this),
                                claimedHashOfEncryptedOutputList);
    mmContract = new mm(partition.challenger, address(subleqContract),
                        claimedHashOfEncryptedOutputList);
    currentState = state.WaitingForMachineToRun;
  }



    getPartitionCurrentState() == partition.state.DivergenceFound

WaitingAcknowledgedResponseToOutputHash
      }

  // this part of the code refers to a disagreement on the transfer of data



  function claimVictoryByDeadline() {
  }

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

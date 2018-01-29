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
  Token public tokenContract; // address of Themis ERC20 contract

  address public client; // who is hiring the provider to perform a calculation
  address public provider; // winner of bit to preform calculation

  bytes32 public clientMachinePreparationHash;
  bytes public clientMachinePreparationURI;
  uint public finalTime;
  bytes8 public addressForSeed;
  uint64 public initialSeed;
  uint64 public numberOfSeeds;

  uint64 public ramSize;
  uint64 public inputMaxSize;
  uint64 public outputMaxSize;

  uint public maxPriceOffered; // maximum price offered for the computation

  address public lowestBidder;
  uint public lowestBid;
  uint public secondLowestBid;
  uint public depositRequired; // deposit necessary in order to participate

  uint public timeOfLastMove; // last time someone made a move with deadline
  uint public auctionDuration; // time dedicated for auction
  uint public roundDuration; // time interval one has before expiration
  uint public jobDuration; // time to perform the job

  bytes32 public claimedHashOfEncryptedOutputList;
  bytes32 public acknowledgedKey;
  uint public amountCommittedToOutputChallenge;
  // for disputes only
  uint64 public sampledSeed;
  bytes32 public decryptionMachinePreparationHash; // hash of machine before key
  bytes32 public decryptionMachineInitialHash; // hash of machine after key
  bytes32 public decryptionMachineFinalHash; // hash of machine after running

  bytes32 public clientMachinePreparationHash; // hash of machine before seed
  bytes32 public clientMachineInitialHash; // hash of machine after seed
  bytes32 public clientMachineFinalHash; // hash of machine after running

  bytes32 public hashOfEncryptedSelectedOuput;
  bytes32 public hashOfDecryptedSelectedOuput; // for unacknowledged challenges

  bytes32 public hashBeforeDivergence; // for the case of run challenge
  bytes32 public hashAfterDivergence; // for the case of run challenge

  // for memory read/write and machine run challenges
  mm public mmContract;
  function getMMCurrentState() view public returns (mm.state) {
    return mmContract.currentState();
  }
  // for memory write challenges
  uint64 positionForMemoryWriteChallenge; // position to write
  bytes32 hashForMemoryWriteChallenge; // hash to be written
  bytes32 finalHashAfterWriteChallenge; // final hash of memory after write

  // for unacknowledged transfers
  bytes32 hashOfDecryptedSolutionList;
  //bytes32 controversialPhraseOfClaimer

  // for binary search in challenges
  partition public partitionContract;
  function getPartitionCurrentState() view public returns (partition.state) {
    return partitionContract.currentState();
  }
  // for simulation during challenges
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
  //     AckKey                              DecrSol
  //       |                                    |
  //     AckApp --                             ...
  //       |      \
  //     AckExp    FSmooth
  //           \
  //      -- AckChal --
  //     /             \
  // MemChall        PartDisp
  //    |               |
  //  FPWOC          MachToRun
  //                    |
  //               FinishMachRun
  //                    |
  //                  FPWMRC


  enum state { WaitingBids, WaitingSolution, WaitingTransferReceipt,
               WaitingAcknowledgedKey, WaitingAcknowledgedApproval,
               WaitingAcknowledgedExplanation, WaitingAcknowledgedChallenge,
               WaitingOutputHashChallenge,
               WaitingInsertionForMemoryChallenge,
               WaitingMemoryWriteChallenge,
               WaitingPartitionDispute, WaitingForMachineToRun,
               WaitingToFinishMachineRunChallenge,
               WaitingDecryptedSolutionHash,
               FinishedNoBidder,
               FinishedSmooth,
               FinishedProviderWonOutputHashChallenge,
               FinishedProviderWonMemoryWriteChallenge,
               FinishedProviderWonMachineRunChallenge
  }

  enum challenge { outputHash, keyInsertion, decyptMachineRun,
                   seedInsertion, clientMachineRun }

  state public currentState;

  event AnounceJob(address theClient, uint theFinalTime,
                   bytes32 theClientMachinePreparationHash,
                   bytes theClientMachinePreparationURI,
                   bytes8 theAddressForSeed, uint64 theInitialSeed,
                   uint64 theNumberOfSeeds, uint64 theRamSize,
                   uint64 theInputMaxSize, uint64 theOutputMaxSize,
                   uint theMaxPriceOffered, uint theDepositRequired,
                   uint theAuctionDuraiton, uint theRoundDuration,
                   uint theJobDuration);
  event LowestBidDecreased(address bidder, uint amount);
  event SolutionPosted(bytes32 theClaimedHashOfEncryptedOutputList);
  //event ChallengePosted(address thePartitionContract);
  //event WinerFound(state finalState);

  function hireCPU(address theClient, uint theFinalTime,
                   bytes32 theClientMachinePreparationHash,
                   bytes theClientMachinePreparationURI,
                   bytes8 theAddressForSeed, uint64 theInitialSeed,
                   uint64 theNumberOfSeeds, uint theMaxPriceOffered,
                   uint theDepositRequired, uint theAuctionDuration,
                   uint theRoundDuration, uint theJobDuration)
    public {

    tokenContract = Token(0xe78A0F7E598Cc8b0Bb87894B0F60dD2a88d6a8Ab);
    client = theClient;

    clientMachinePreparationHash = theClientMachinePreparationHash;
    clientMachinePreparationURI = theClientMachinePreparationURI;

    require(theFinalTime > 0);
    finalTime = theFinalTime;

    addressForSeed = theAddressForSeed;
    // there should be no overflow in the sum below
    require(theInitialSeed + theNumberOfSeeds > theInitialSeed);
    // all hashes must fit mm and each hash takes 4 words
    require(theInitialSeed + theNumberOfSeeds < uint64(0x4000000000000000));

    initialSeed = theInitialSeed;
    numberOfSeeds = theNumberOfSeeds;

    ramSize = theRamSize;
    inputMaxSize = theInputMaxSize;
    outputMaxSize = theOutputMaxSize;

    maxPriceOffered = theMaxPriceOffered;
    lowestBid = theMaxPriceOffered;
    depositRequired = theDepositRequired;
    tokenContract.transferFrom(msg.sender, address(this), theMaxPriceOffered);

    auctionDuration = theAuctionDuration;
    roundDuration = theRoundDuration;
    jobDuration = theJobDuration;
    timeOfLastMove = now;

    currentState = state.WaitingBids;
    AnounceJob(client, finalTime, clientMachinePreparationHash,
               clientMachinePreparationURI,
               addressForSeed, initialSeed, numberOfSeeds, maxPriceOffered,
               depositRequired, auctionDuration, roundDuration,
               jobDuration);
  }

  /// @notice Post a bid for the announced job
  /// @param numberOfTokens required by bidder to perform the computation
  function bid(uint numberOfTokens) public {
    require(currentState == state.WaitingBids);
    require(numberOfTokens < lowestBid);
    tokenContract.transferFrom(msg.sender, address(this), depositRequired);
    // if there was a previous bid with a deposit, reimburse the previous bidder
    if (lowestBidder != address(0)) {
      tokenContract.transfer(lowestBidder, depositRequired);
    }
    lowestBidder = msg.sender;
    lowestBid = numberOfTokens;
    LowestBidDecreased(msg.sender, numberOfTokens);
  }

  /// @notice Finishes the auction, if there is no bid, send deposit back to
  /// client
  function finishAuctionPhase() public {
    require(currentState == state.WaitingBids);
    require(now > timeOfLastMove + auctionDuration);
    // check if lowestBidder was unset and then send ballance back to client
    if (lowestBidder == address(0)) {
      uint balance = tokenContract.ballanceOf(address(this));
      tokenContract.transfer(client, balance);
      currentState = state.FinishedNoBidder;
    } else {
      provider = lowestBidder;
      timeOfLastMove = now;
      currentState = state.WaitingSolution;
    }
  }

  /// @notice Provider posts the Merkel tree hash of a memory contataining the
  /// Merkel tree hashes of all the encrypted outputs from the client machine
  /// as we vary the seeds
  /// @param theClaimedHashOfEncryptedOutputList the hash of the memory
  function postSolution(bytes32 theClaimedHashOfEncryptedOutputList) public {
    require(msg.sender == provider);
    require(currentState == state.WaitingSolution);
    claimedHashOfEncryptedOutputList = theClaimedHashOfEncryptedOutputList;
    currentState = state.WaitingTransferReceipt;
    timeOfLastMove = now;
    SolutionPosted(claimedHashOfEncryptedOutputList);
  }

  /// @notice Client acknowledges the transfer of data (off-chain), from the
  /// provider.
  function acknowledgeTransfer() public {
    require(msg.sender == client);
    require(currentState == state.WaitingTransferReceipt);
    timeOfLastMove = now;
    currentState = state.WaitingAcknowledgedKey;
  }

  /// @notice Provider sends the key to decrypt the outputs sent in the previous
  /// step in case the transfer of data between provider and client was
  /// acknowledged
  /// @param theAcknowledgedKey the key
  function sendAcknowledgedKey(bytes32 theAcknowledgedKey) public {
    require(msg.sender == provider);
    require(currentState == state.WaitingAcknowledgedKey);
    timeOfLastMove = now;
    acknowledgedKey = theAcknowledgedKey;
    currentState = state.WaitingAcknowledgedApproval;
  }

  /// @notice Client approves payment of the job for having confirmed that the
  /// calculation was done correctly for several seeds
  function aproveAcknowledgedCalculation() public {
    require(msg.sender == client);
    require(currentState == state.WaitingAcknowledgedApproval);
    timeOfLastMove = now;
    tokenContract.transfer(provider, depositRequired + lowestBid);
    currentState = state.FinishedSmooth;
  }

  /// @notice Client has acknowledged the receipt of outputs but she disagrees
  /// on the calculation of a certain seed
  /// @param theSampledSeed the index of the seed that was not aggreed uppon
  function disaproveAcknowledgedCalculation(uint64 theSampledSeed) public {
    require(msg.sender == client);
    require(currentState == state.WaitingAcknowledgedApproval);
    require(theSampledSeed >= initialSeed);
    require(theSampledSeed < initialSeed + numberOfSeeds);
    tokenContract.transferFrom(client, address(this), depositRequired);
    sampledSeed = theSampledSeed;
    timeOfLastMove = now;
    currentState = state.WaitingAcknowledgedExplanation;
  }

  /// @notice Provider sends all the hashes that are necessary to prove
  /// that his calculations are correct for the sampled seed
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
    // 0x00000... has to be replaced by the merkel hash of 2^62 zeros
    // 0x11111... has to be replaced by our machine hash
    // 0x22222... has to be replaced by our decryption hd hash

    // assemble decryption machine preparation hash
    bytes32 machine = keccak256
      ( 0x1111111111111111111111111111111111111111111111111111111111111111,
        0x2222222222222222222222222222222222222222222222222222222222222222
        );
    bytes32 inputOutput = keccak256
      ( hashOfEncryptedSelectedOuput,
        0x0000000000000000000000000000000000000000000000000000000000000000
        );
    decryptionMachinePreparationHash = keccak256(machine, inputOutput);
    // store the decryption machine initial hash
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
    // store the client machine initial hash
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

  /// @notice Client has acknowledged the receipt of the output data,
  /// but disagrees in some calculation. Having received the explanation
  /// from the provider, she now must decide what part of the calculation
  /// she disagrees with
  /// @param theChallenge the type of challenge she will present with the
  /// choices:
  ///  - outputHash: dispute that claimedHashOfEncryptedOutputList
  ///    points to hashOfEncryptedSelectedOutput at position sampledSeed
  ///  - keyInsertion: dispute that inserting the key into the
  ///    decryption machine does not yield decryptionMachineInitialHash
  ///  - decyptMachineRun: dispute that running the machine from
  ///    decryptionMachineInitialHash for time 2^64 will give finish with
  ///    decryptionMachineFinalHash
  ///  - seedInsertion: dispute that inserting the sampledSeed into the
  ///    client machine yields clientMachineInitialHash
  ///  - clientMachineRun: dispute that running the machine from
  ///    clientMachineInitialHash will give finish with
  ///    clientMachineFinalHash
  function postAcknowledgedChallenge(challenge theChallenge) {
    require(msg.sender == client);
    require(currentState = state.WaitingAcknowledgedChallenge);
    if (theChallenge == challenge.outputHash) {
      amountCommittedToOutputChallenge = 2 * depositRequired + lowestBid;
      mmContract = new mm(provider, address(this),
                          claimedHashOfEncryptedOutputList);
      currentState = state.WaitingOutputHashChallenge;
    }
    if (theChallenge == challenge.keyInsertion) {
      // replace this by the position of the key in decryption machine memory
      positionForMemoryWriteChallenge = 0x8888888888880000;
      hashForMemoryWriteChallenge = acknowledgedKey;
      finalHashAfterWriteChallenge = decryptionMachineInitialHash;
      mmContract = new mm(provider, address(this),
                          decryptionMachinePreparationMemory);
      currentState = state.WaitingInsertionForMemoryChallenge;
    }
    if (theChallenge == challenge.decryptMachineRun) {
      partitionContract = new partition(client, provider,
                                        decryptionMachineInitialHash,
                                        decryptionMachineFinalHash,
                                        2**64, 10, roundDuration);
      currentState = state.WaitingPartitionDispute;
    }
    if (theChallenge == challenge.seedInsertion) {
      positionForMemoryWriteChallenge = addressForSeed;
      // care for the endianness of the machine
      hashForMemoryWriteChallenge = uint256(sampledSeed);
      finalHashAfterWriteChallenge = clientMachineInitialHash;
      mmContract = new mm(provider, address(this),
                          clientMachinePreparationHash);
      currentState = state.WaitingInsertionForMemoryChallenge;
    }
    if (theChallenge == challenge.clientMachineRun) {
      partitionContract = new partition(client, provider,
                                        clientMachineInitialHash,
                                        clientMachineFinalHash,
                                        finalTime, 10, roundDuration);
      currentState = state.WaitingPartitionDispute;
    }
    timeOfLastMove = now;
  }

  /// @notice Provider has a way to prove that he was correct in the output
  /// challenge. In this case he fills the appropriate parts of the memory with
  /// the corresponding pieces of the output hash and calls this function.
  function settleOutputHashChallenge() {
    require(msg.sender == provider);
    require(currentState = state.WaitingOutputHashChallenge);
    require(getMMCurrentState() == mm.state.Reading);
    bytes8 word1 = mm.read(32 * sampledSeed);
    bytes8 word2 = mm.read(32 * sampledSeed + 8);
    bytes8 word3 = mm.read(32 * sampledSeed + 16);
    bytes8 word4 = mm.read(32 * sampledSeed + 24);
    word = bytes32(word1);
    word |= bytes32(word2) >> 64;
    word |= bytes32(word3) >> 128;
    word |= bytes32(word4) >> 192;
    require(word == hashOfEncryptedSelectedOutput);
    tokenContract.transfer(provider, amountCommittedToOutputChallenge);
    // transfer the rest to client
    uint balance = tokenContract.ballanceOf(address(this));
    tokenContract.transfer(client, balance);
    currentState = state.FinishedProviderWonOutputHashChallenge;
  }

  /// @notice In case of a memory challenge, this function should be called
  /// so that the contract will write hashForMemoryWriteChallenge in the
  /// position pointed by positionForMemoryWriteChallenge.
  function insertionForMemoryWriteChallenge() {
    require(msg.sender == provider);
    require(currentState = state.WaitingInsertionForMemoryChallenge);
    require(getMMCurrentState() == mm.state.Reading);
    bytes8 word1 = bytes8(hashForMemoryWriteChallenge);
    bytes8 word2 = bytes8(hashForMemoryWriteChallenge << 64);
    bytes8 word3 = bytes8(hashForMemoryWriteChallenge << 128);
    bytes8 word4 = bytes8(hashForMemoryWriteChallenge << 192);
    mm.write(positionForMemoryWriteChallenge, word1);
    mm.write(positionForMemoryWriteChallenge + 8, word2);
    mm.write(positionForMemoryWriteChallenge + 16, word3);
    mm.write(positionForMemoryWriteChallenge + 24, word4);
    timeOfLastMove = now;
    currentState = state.WaitingMemoryWriteChallenge;
  }

  /// @notice After the provider having updated the hash of mm to
  /// account for the memory insertion done in insertionForMemoryWriteChallenge,
  /// the provider calls this function to prove that he was correct in the
  /// memory insertion challenge.
  function settleMemoryWriteChallenge() {
    require(msg.sender == provider);
    require(currentState = state.WaitingMemoryWriteChallenge);
    require(getMMCurrentState() == mm.state.Finished);
    require(mm.newHash == finalHashAfterWriteChallenge);
    tokenContract.transfer(provider, 2 * depositRequired + lowestBid);
    currentState = state.FinishedProviderWonMemoryWriteChallenge;
  }

  /// @notice In case one of the parties wins the partition challenge by
  /// timeout, then he or she can call this function to claim victory in
  /// the hireCPU contract as well.
  function winByPartitionTimeout() {
    require(currentState == state.WaitingPartitionDispute);
    if (getPartitionCurrentState() == partition.state.ChallengerWon) {
      tokenContract.transfer(client, 2 * depositRequired + lowestBid);
      currentState = state.Finished;
    }
    if (getPartitionCurrentState() == partition.state.ClaimerWon) {
      tokenContract.transfer(provider, 2 * depositRequired + lowestBid);
      currentState = state.Finished;
    }
  }

  /// @notice After the partition challenge has lead to a divergence in the hash
  /// within one time step, anyone can start a mechine run challenge to decide
  /// whether the provider was correct about that particular step transition.
  /// This function call solely instantiate a memory manager, so the the
  /// provider can fill the appropriate addresses that will be read by the
  /// machine.
  function startMachineRunChallenge() {
    require(currentState == state.WaitingPartitionDispute);
    require(getPartitionCurrentState() == partition.state.DivergenceFound);
    uint divergenceTime = partitionContract.divergenceTime;
    hashBeforeDivergence = partitionContract.timeHash[divergenceTime];
    hashAfterDivergence = partitionContract.timeHash[divergenceTime + 1];
    mmContract = new mm(provider, address(this), hashBeforeDivergence);
    timeOfLastMove = now;
    currentState = state.WaitingForMachineToRun;
  }

  /// @notice After having filled the memory manager with the necessary data,
  /// the provider calls this function to instantiate the machine and perform
  /// one step on it. The machine will write to memory in the process and the
  /// provider will be expected to update the memory hash accordingly.
  function continueMachineRunChallenge() {
    require(msg.sender == provider);
    require(currentState == state.WaitingForMachineToRun);
    subleqContract = new subleq(address(mmContract), ramSize, inputMaxSize,
                                outputMaxSize);
    mmContract.changeClient(address(subleqContract));
    uint8 result = subleqContract.step();
    timeOfLastMove = now;
    currentState = state.WaitingToFinishMachineRunChallenge;
  }

  /// @notice After having updated to memory to account for the addresses
  /// that were written by the machine, the provider now calls this function
  /// to settle the challenge in his favour.
  function settleMachineRunChallenge() {
    require(msg.sender == provider);
    require(currentState == state.WaitingToFinishMachineRunChallenge);
    require(getMMCurrentState() == mm.state.Finished);
    require(mm.newHash != hashAfterDivergence);
    tokenContract.transfer(client, 2 * depositRequired + lowestBid);
    currentState = state.FinishedProviderWonMachineRunChallenge;
  }

  // this part of the code refers to a disagreement on the transfer of data

  /// @notice Client denies that the data from provider was available
  // off-chain and this starts the "unacklowledge" challenges
  function denyTransfer() public {
    require(msg.sender == client);
    require(currentState == state.WaitingTransferReceipt);
    timeOfLastMove = now;
    currentState = state.WaitingDecryptedSolutionHash;
  }

  /// @notice Having noticed that the Client claimed that the data was not
  /// available off-chain, the provider sends the hash for the unencrypted
  /// outputs in order to prove that he has done the calculations without
  /// providing the client with their contents.
  /// @param theHashOfDecryptedSolutionList the hash of the memory containing
  /// the unencrypted outputs.
  function sendDecryptedSolution(bytes32 theHashOfDecryptedSolutionList) public
  {
    require(msg.sender == provider);
    require(currentState == state.WaitingDecryptedSolutionHash);
    hashOfDecryptedSolutionList = theHashOfDecryptedSolutionList;
    timeOfLastMove = now;
    currentState = state.WaitingUnacknowledgedSampleSeed;
  }

  /// @notice The client gives one random seed to verify whether the provider
  /// has indeed made that specific calculation.
  /// @param theSampleSeed the index of the seed to be sampled.
  function giveUnacknowledgedSampleSeed (uint64 theSampleSeed) public {
    require(msg.sender == client);
    require(currentState == state.WaitingUnacknowledgedSampleSeed);
    require(theSampledSeed >= initialSeed);
    require(theSampledSeed < initialSeed + numberOfSeeds);
    sampledSeed = theSampledSeed;
    timeOfLastMove = now;
    currentState = state.WaitingUncknowledgedExplanation;
  }

  /// @notice Provider sends all the hashes that are necessary to prove
  /// that his calculations are correct for the controversial hash
  function giveUnacknowledgedExplanation
    ( bytes32 theClientMachineInitialHash,
      bytes32 theFinal1HashOfClientMachine,
      bytes32 theFinal2HashOfClientMachine,
      bytes32 theFinal3HashOfClientMachine,
      bytes32 theHashOfDecryptedSelectedOutput
      ) {
    require(msg.sender == provider);
    require(currentState = state.WaitingUnacknowledgedExplanation);
    // store the client machine initial hash
    clientMachineInitialHash = theClientMachineInitialHash;
    // assemble client machine final hash
    hashOfDecryptedSelectedOutput = theHashOfDecryptedSelectedOutput;
    machine = keccak256
      ( theFinal1HashOfClientMachine,
        theFinal2HashOfClientMachine,
        );
    inputOutput = keccak256
      ( theFinal3HashOfClientMachine,
        hashOfDecryptedSelectedOutput
        );
    clientMachineFinalHash = keccak256(machine, inputOutput);
    timeOfLastMove = now;
    currentState = state.WaitingUnacknowledgedChallenge;
  }

  /// @notice Client has not acknowledged the receipt of the output data.
  /// After sampling an output for test she received the explanation
  /// from the provider, she now must decide what part of the calculation
  /// she wants to challenge
  /// @param theChallenge the type of challenge she will present with the
  /// choices:
  ///  - outputHash: dispute that hashOfDecryptedSolutionList
  ///    points to hashOfDecryptedSelectedOutput at position sampledSeed
  ///  - seedInsertion: dispute that inserting the sampledSeed into the
  ///    client machine yields clientMachineInitialHash (needs payment)
  ///  - clientMachineRun: dispute that running the machine from
  ///    clientMachineInitialHash will give finish with
  ///    clientMachineFinalHash (needs payment)
  function postUnacknowledgedChallenge(challenge theChallenge) {
    require(msg.sender == client);
    require(currentState = state.WaitingUnacknowledgedChallenge);
    if (theChallenge == challenge.outputHash) {
      amountCommittedToOutputChallenge = depositRequired + lowestBid/2;
      mmContract = new mm(provider, address(this),
                          hashOfDecryptedSolutionList);
      currentState = state.WaitingOutputHashChallenge;
    }
    if (theChallenge == challenge.seedInsertion) {
      tokenContract.transferFrom(client, address(this), depositRequired);
      positionForMemoryWriteChallenge = addressForSeed;
      // care for the endianness of the machine
      hashForMemoryWriteChallenge = uint256(sampledSeed);
      finalHashAfterWriteChallenge = clientMachineInitialHash;
      mmContract = new mm(provider, address(this),
                          clientMachinePreparationHash);
      currentState = state.WaitingInsertionForMemoryChallenge;
    }
    if (theChallenge == challenge.clientMachineRun) {
      tokenContract.transferFrom(client, address(this), depositRequired);
      partitionContract = new partition(client, provider,
                                        clientMachineInitialHash,
                                        clientMachineFinalHash,
                                        finalTime, 10, roundDuration);
      currentState = state.WaitingPartitionDispute;
    }
    timeOfLastMove = now;
  }

  /// @notice Any party can claim victory if the other has lost the deadline
  /// for some of the steps in the protocol.
  function claimVictoryByDeadline() {
    if (msg.sender == client) {
      if ((currentState == state.WaitingAcknowledgedKey)
          || (currentState == state.WaitingAcknowledgedExplanation)
          || (currentState == state.WaitingOutputHashChallenge)
          || (currentState == state.WaitingInsertionForMemoryChallenge)
          || (currentState == state.WaitingMemoryWriteChallenge)
          || (currentState == state.WaitingForMachineToRun)
          || (currentState == state.WaitingToFinishMachineRunChallenge)
          || (currentState == state.WaitingDecryptedSolutionHash)
          || (currentState == state.WaitingUnacknowledgedExplanation)) {
        if (now > timeOfLastMove + roundDuration) {
          uint balance = tokenContract.ballanceOf(address(this));
          tokenContract.transfer(client, balance);
          currentState = state.Finished;
          ChallengeEnded(currentState);
        }
      }
      if ((currentState == state.WaitingSolution)
          && (now > timeOfLastMove + jobDuration)) {
        uint balance = tokenContract.ballanceOf(address(this));
        tokenContract.transfer(client, balance);
        currentState = state.Finished;
        ChallengeEnded(currentState);
      }
    }
    if (msg.sender == provider) {
      if ((currentState == state.acknowledgeTransfer)
          || (currentState == state.WaitingAcknowledgedApproval)
          || (currentState == state.WaitingAcknowledgedChallenge)
          || (currentState == state.WaitingUnacknowledgedSampleSeed)
          || (currentStata == state.WaitingUnacknowledgedChallenge)) {
        if (now > timeOfLastMove + roundDuration) {
          uint balance = tokenContract.ballanceOf(address(this));
          tokenContract.transfer(provider, balance);
          currentState = state.Finished;
          ChallengeEnded(currentState);
        }
      }
    }
  }

  // to kill the contract and receive refunds
  function killContract() public {
    require(currentState == state.Finished);
    uint balance = tokenContract.balanceOf(address(this));
    tokenContract.transfer(client, balance);
    selfdestruct(client);
  }
}

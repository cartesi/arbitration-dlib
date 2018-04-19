/// @title Betting contract
pragma solidity ^0.4.0;

//import "./MMLib.sol";
import "./SubleqLib.sol";
import "./PartitionLib.sol";
import "./lib/bokkypoobah/Token.sol";

contract MCProtocol
{
  using MMLib for MMLib.MMCtx;
  MMLib.MMCtx mm;

  using PartitionLib for PartitionLib.PartitionCtx;
  PartitionLib.PartitionCtx partition;

  using SubleqLib for SubleqLib.SubleqCtx;
  SubleqLib.SubleqCtx subleq;

  Token public tokenContract; // address of Themis ERC20 contract

  address public client; // who is hiring the provider for a calculation
  address public provider; // winner of bit to preform calculation
  bytes32 public claimedHashOutputList; // provider's hash of encrypted outputs
  uint public timeOfLastMove; // last time someone made a move with deadline
  uint public valueOutputChallenge; // prize for winner of output challenge

  struct computationCtx // the information describing the computation
  {
    bytes32 preparationHash; // hash of machine before seed
    bytes URI; // a URI indicating where to get the preparation machine
    uint time; // the total time for which this machine should run
    uint64 seedAddress; // the address in the machine to be replaced by seed
    uint64 seedNumber; // the number of seeds to run (starting from zero)
  }
  computationCtx public computation;

  struct parametersCtx // general information concerning the task
  {
    uint maxPrice; // maximum price offered for the computation
    uint deposit; // deposit necessary in order to participate
    uint roundDuration; // time interval to interact with this contract
    uint jobDuration; // time to perform the job
  }
  parametersCtx public parameters;

  struct auctionCtx // the information concerning the bidding (Vickrey) process
  {
    address lowestBidder; // the address of the lowest bidder (zero if none)
    uint lowestBid; // the value of the lowest bid
    uint contractedPrice; // the second price (since this is a Vickey auction)
    uint duration; // time dedicated for auction
  }
  auctionCtx public auction;

  struct acknowledgedCtx // for challenge if client acknowledges receiving data
  {
    bytes32 key; // key to decrypt the received outputs
    uint64 seed; // the seed of an output that is to be challenged
    bytes32 hashEncryptedSelectedOutput; // hash of encrypted output of seed
    bytes32 decryptionPreparationHash; // machine hash before key insertion
    bytes32 decryptionInitialHash; // machine hash after key insertion
    bytes32 decryptionFinalHash; // hash of machine after running
    bytes32 clientMachineInitialHash; // hash of machine after seed inserted
    bytes32 clientMachineFinalHash; // hash of machine after running
  }
  acknowledgedCtx public acknowledged;

  struct unacknowledgedCtx // for challenge if client denied receipt of data
  {
    bytes32 hashOutputList; // hash of memory containing hashes of outputs
    uint64 seed; // index of seed to be tested
    bytes32 hashSelectedOutput; // hash for output pointed by seed
    bytes32 clientMachineInitialHash; // hash of machine after seed inserted
    bytes32 clientMachineFinalHash; // hash of machine after running
  }
  unacknowledgedCtx public unacknowledged;

  struct writeChallengeCtx // challenges that involve writing in memory
  {
    uint64 position; // position to write
    bytes32 initialHash; // hash to be written
    bytes32 finalHash; // final hash of memory after writing
  }
  writeChallengeCtx public writeChallenge;

  struct runChallengeCtx // challenges that involve running a machine
  {
    bytes32 hashBeforeDivergence; // for the case of run challenge
    bytes32 hashAfterDivergence; // for the case of run challenge
  }
  runChallengeCtx public runChallenge;

  // These are the possible (abbreviated) states of the contract,
  // see the full names below:
  //
  //                               Bids --
  //                                |     \
  //                               Sol     FNoBidder
  //                                |
  //         -------------------- TrRec -------
  //        /                                  \
  //     AckKey                              DecrSol
  //       |                                    |
  //     AckApp --                          UnackSamp
  //       |      \                             |
  //     AckExp    FSmooth                  UnackExpl
  //       |                                    |
  //     AckChal ---------------------    - UnackChal
  //       \   \                      \  /     /    |
  //        \   ------------      ---- \      /     |
  //         \              \    /      \    /     /
  //          \     -------  \  -   ---- \ --     /
  //           \   /          \    /      \      /
  //         OutChall      InsertChal     PartDisp
  //            |              |             |
  //          FPWOC       MemWriteChal   MachToRun
  //                           |             |
  //                        FPWMWC      FinishMachRun
  //                                         |
  //                                       FPWMRC
  //
  // Besides these states, there are four states that relate to
  // timeout by any of the parties: two for timeout in the partition
  // contract and two for timeout here.

  enum state { WaitBids, WaitSolution, WaitTransferReceipt,
               WaitAcknowledgedKey, WaitAcknowledgedApproval,
               WaitAcknowledgedExplanation, WaitAcknowledgedChallenge,
               WaitOutputHashChallenge, WaitInsertionForMemoryChallenge,
               WaitMemoryWriteChallenge, WaitPartitionDispute,
               WaitForMachineToRun, WaitToFinishMachineRunChallenge,
               WaitDecryptedSolutionHash, WaitUnacknowledgedSampleSeed,
               WaitUnacknowledgedExplanation, WaitUnacknowledgedChallenge,
               FinishedNoBidder, FinishedSmooth,
               FinishedProviderWonOutputHashChallenge,
               FinishedProviderWonMemoryWriteChallenge,
               FinishedProviderWonMachineRunChallenge,
               FinishedPartitionProviderTimeout,
               FinishedPartitionClientTimeout,
               FinishedProviderTimeout, FinishedClientTimeout
  }

  enum challenge { outputHash, keyInsertion, decryptMachineRun,
                   seedInsertion, clientMachineRun }

  state public currentState;

  event AnounceJob(uint _finalTime, bytes32 _clientMachinePreparationHash,
                   bytes _clientMachinePreparationURI,
                   uint64 _addressForSeed, uint64 _numberOfSeeds,
                   uint _maxPrice, uint _depositRequired,
                   uint _roundDuration, uint _jobDuration);

  event LowestBidDecreased(address bidder, uint amount);
  event SolutionPosted(bytes32 _claimedHashOutputList);
  //event ChallengePosted(address _partitionContract);
  //event WinerFound(state finalState);
  event ChallengeEnded(state);

  function hireCPU(address _client, uint _finalTime,
                   bytes32 _clientMachinePreparationHash,
                   bytes _clientMachinePreparationURI,
                   uint64 _addressForSeed, uint64 _initialSeed,
                   uint64 _numberOfSeeds, uint _maxPrice, uint _depositRequired,
                   uint _auctionDuration, uint _roundDuration,
                   uint _jobDuration)
    public {

    tokenContract = Token(0xe78A0F7E598Cc8b0Bb87894B0F60dD2a88d6a8Ab);
    client = _client;

    computation.preparationHash = _clientMachinePreparationHash;
    computation.URI = _clientMachinePreparationURI;

    require(_finalTime > 0);
    computation.time = _finalTime;

    computation.seedAddress = _addressForSeed;
    // there should be no overflow in the sum below
    require(_initialSeed + _numberOfSeeds > _initialSeed);
    // all hashes must fit mm and each hash takes 4 words
    require(_initialSeed + _numberOfSeeds < uint64(0x4000000000000000));

    computation.seedNumber = _numberOfSeeds;

    parameters.maxPrice = _maxPrice;
    auction.lowestBid = _maxPrice;
    parameters.deposit = _depositRequired;
    tokenContract.transferFrom(msg.sender, address(this), _maxPrice);

    auction.duration = _auctionDuration;
    parameters.roundDuration = _roundDuration;
    parameters.jobDuration = _jobDuration;
    timeOfLastMove = now;

    currentState = state.WaitBids;
    emit AnounceJob(computation.time, computation.preparationHash,
                    computation.URI, computation.seedAddress,
                    computation.seedNumber, parameters.maxPrice,
                    parameters.deposit, parameters.roundDuration,
                    parameters.jobDuration);
  }

  /// @notice Post a bid for the announced job (Vickey auction)
  /// @param numberOfTokens required by bidder to perform the computation
  function bid(uint numberOfTokens) public {
    require(currentState == state.WaitBids);
    require(numberOfTokens < 99 * (auction.lowestBid / 100));
    tokenContract.transferFrom(msg.sender, address(this), parameters.deposit);
    // if there was a previous bid with a deposit, reimburse the previous bidder
    if (auction.lowestBidder != address(0)) {
      tokenContract.transfer(auction.lowestBidder, parameters.deposit);
    }
    auction.lowestBidder = msg.sender;
    auction.contractedPrice = auction.lowestBid;
    auction.lowestBid = numberOfTokens;
    emit LowestBidDecreased(msg.sender, numberOfTokens);
  }

  /// @notice Finishes the auction. If there is no bid, send deposit back to
  /// client
  function finishAuctionPhase() public {
    require(currentState == state.WaitBids);
    require(now > timeOfLastMove + auction.duration);
    // check if lowestBidder was unset and then send balance back to client
    if (auction.lowestBidder == address(0)) {
      uint balance = tokenContract.balanceOf(address(this));
      tokenContract.transfer(client, balance);
      currentState = state.FinishedNoBidder;
    } else {
      provider = auction.lowestBidder;
      timeOfLastMove = now;
      currentState = state.WaitSolution;
    }
  }

  /// @notice Provider posts the Merkel tree hash of a memory contataining the
  /// Merkel tree hashes of all the encrypted outputs from the client machine
  /// as we vary the seeds
  /// @param _claimedHashOutputList the hash of the memory
  function postSolution(bytes32 _claimedHashOutputList) public {
    require(msg.sender == provider);
    require(currentState == state.WaitSolution);
    claimedHashOutputList = _claimedHashOutputList;
    currentState = state.WaitTransferReceipt;
    timeOfLastMove = now;
    emit SolutionPosted(claimedHashOutputList);
  }

  /// @notice Client acknowledges the transfer of data (off-chain), from the
  /// provider. The data includes all the encrypted outputs.
  function acknowledgeTransfer() public {
    require(msg.sender == client);
    require(currentState == state.WaitTransferReceipt);
    timeOfLastMove = now;
    currentState = state.WaitAcknowledgedKey;
  }

  /// @notice Provider sends the key to decrypt the outputs sent in the previous
  /// step in case the transfer of data between provider and client was
  /// acknowledged
  /// @param _acknowledgedKey the key
  function sendAcknowledgedKey(bytes32 _acknowledgedKey) public {
    require(msg.sender == provider);
    require(currentState == state.WaitAcknowledgedKey);
    timeOfLastMove = now;
    acknowledged.key = _acknowledgedKey;
    currentState = state.WaitAcknowledgedApproval;
  }

  /// @notice Client approves payment of the job for having confirmed that the
  /// calculation was done correctly for several seeds
  function aproveAcknowledgedCalculation() public {
    require(msg.sender == client);
    require(currentState == state.WaitAcknowledgedApproval);
    timeOfLastMove = now;
    tokenContract.transfer(provider,
                           parameters.deposit + auction.contractedPrice);
    currentState = state.FinishedSmooth;
  }

  /// @notice Client has acknowledged the receipt of outputs but she disagrees
  /// on the calculation of a certain seed
  /// @param _seed the index of the seed that was not aggreed uppon
  function disaproveAcknowledgedCalculation(uint64 _seed) public {
    require(msg.sender == client);
    require(currentState == state.WaitAcknowledgedApproval);
    require(_seed < computation.seedNumber);
    tokenContract.transferFrom(client, address(this), parameters.deposit);
    acknowledged.seed = _seed;
    timeOfLastMove = now;
    currentState = state.WaitAcknowledgedExplanation;
  }

  /// @notice Provider sends all the hashes that are necessary to prove
  /// that his calculations are correct for the sampled seed
  function giveAcknowledgedExplanation
    ( bytes32 _hashEncryptedSelectedOutput,
      bytes32 _decryptionInitialHash,
      bytes32 _final1HashOfDecryptMachine,
      bytes32 _final2HashOfDecryptMachine,
      bytes32 _final3HashOfDecryptMachine,
      bytes32 _final4HashOfDecryptMachine,
      bytes32 _clientMachineInitialHash,
      bytes32 _final1HashOfClientMachine,
      bytes32 _final2HashOfClientMachine,
      bytes32 _final3HashOfClientMachine
      ) public {
    require(msg.sender == provider);
    require(currentState == state.WaitAcknowledgedExplanation);
    acknowledged.hashEncryptedSelectedOutput = _hashEncryptedSelectedOutput;
    // 0x00000... has to be replaced by the merkel hash of 2^62 zeros
    // 0x11111... has to be replaced by our machine hash
    // 0x22222... has to be replaced by our decryption hd hash

    // assemble decryption machine preparation hash
    bytes32 machine = keccak256
      ( bytes32(0x1111111111111111111111111111111111111111111111111111111111111111),
        bytes32(0x2222222222222222222222222222222222222222222222222222222222222222)
        );
    bytes32 inputOutput = keccak256
      ( acknowledged.hashEncryptedSelectedOutput,
        bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );
    acknowledged.decryptionPreparationHash = keccak256(machine, inputOutput);
    // store the decryption machine initial hash
    acknowledged.decryptionInitialHash = _decryptionInitialHash;
    // assemble decryption machine final hash
    machine = keccak256
      ( _final1HashOfDecryptMachine,
        _final2HashOfDecryptMachine
        );
    inputOutput = keccak256
      ( _final3HashOfDecryptMachine,
        _final4HashOfDecryptMachine
        );
    acknowledged.decryptionFinalHash = keccak256(machine, inputOutput);
    // store the client machine initial hash
    acknowledged.clientMachineInitialHash = _clientMachineInitialHash;
    // assemble client machine final hash
    machine = keccak256
      ( _final1HashOfClientMachine,
        _final2HashOfClientMachine
        );
    inputOutput = keccak256
      ( _final3HashOfClientMachine,
        _final4HashOfDecryptMachine
        );
    acknowledged.clientMachineFinalHash = keccak256(machine, inputOutput);
    timeOfLastMove = now;
    currentState = state.WaitAcknowledgedChallenge;
  }

  /// @notice Client has acknowledged the receipt of the output data,
  /// but disagrees in some calculation. Having received the explanation
  /// from the provider, she now must decide what part of the calculation
  /// she disagrees with
  /// @param _challenge the type of challenge she will present with the
  /// choices:
  ///  - outputHash: dispute that claimedHashOutputList
  ///    points to hashEncryptedSelectedOutput at position acknowledged.seed
  ///  - keyInsertion: dispute that inserting the key into the
  ///    decryption machine does not yield acknowledged.decryptionInitialHash
  ///  - decryptMachineRun: dispute that running the machine from
  ///    decrryptionMachineInitialHash for time 2^64 will give finish with
  ///    acknowledged.decryptionFinalHash
  ///  - seedInsertion: dispute that inserting the acknowledged.seed into the
  ///    client machine yields acknowledged.clientMachineInitialHash
  ///  - clientMachineRun: dispute that running the machine from
  ///    acknowledged.clientMachineInitialHash will give finish with
  ///    acknowledged.clientMachineFinalHash
  function postAcknowledgedChallenge(challenge _challenge) public {
    require(msg.sender == client);
    require(currentState == state.WaitAcknowledgedChallenge);
    if (_challenge == challenge.outputHash) {
      valueOutputChallenge = 2 * parameters.deposit
        + auction.contractedPrice;
      mm.init(provider, address(this), claimedHashOutputList);
      currentState = state.WaitOutputHashChallenge;
    }
    if (_challenge == challenge.keyInsertion) {
      // replace this by the position of the key in decryption machine memory
      writeChallenge.position = 0x8888888888880000;
      writeChallenge.initialHash = acknowledged.key;
      writeChallenge.finalHash = acknowledged.decryptionInitialHash;
      mm.init(provider, address(this),
              acknowledged.decryptionPreparationHash);
      currentState = state.WaitInsertionForMemoryChallenge;
    }
    if (_challenge == challenge.decryptMachineRun) {
      partition.init(client, provider, acknowledged.decryptionInitialHash,
                     acknowledged.decryptionFinalHash, 2**64, 10,
                     parameters.roundDuration);
      currentState = state.WaitPartitionDispute;
    }
    if (_challenge == challenge.seedInsertion) {
      writeChallenge.position = computation.seedAddress;
      // care for the endianness of the machine
      writeChallenge.initialHash = bytes32(uint256(acknowledged.seed));
      writeChallenge.finalHash = acknowledged.clientMachineInitialHash;
      mm.init(provider, address(this), computation.preparationHash);
      currentState = state.WaitInsertionForMemoryChallenge;
    }
    if (_challenge == challenge.clientMachineRun) {
      partition.init(client, provider, acknowledged.clientMachineInitialHash,
                     acknowledged.clientMachineFinalHash, computation.time, 10,
                     parameters.roundDuration);
      currentState = state.WaitPartitionDispute;
    }
    timeOfLastMove = now;
  }

  /// @notice Provider has a way to prove that he was correct in the output
  /// challenge. In this case he fills the appropriate parts of the memory with
  /// the corresponding pieces of the output hash and calls this function.
  function settleOutputHashChallenge() public {
    require(msg.sender == provider);
    require(currentState == state.WaitOutputHashChallenge);
    require(mm.currentState == MMLib.state.Reading);
    bytes8 word1 = mm.read(uint64(32 * acknowledged.seed));
    bytes8 word2 = mm.read(uint64(32 * acknowledged.seed + 8));
    bytes8 word3 = mm.read(uint64(32 * acknowledged.seed + 16));
    bytes8 word4 = mm.read(uint64(32 * acknowledged.seed + 24));
    bytes32 word;
    word = bytes32(word1);
    word |= bytes32(word2) >> 64;
    word |= bytes32(word3) >> 128;
    word |= bytes32(word4) >> 192;
    require(word == acknowledged.hashEncryptedSelectedOutput);
    tokenContract.transfer(provider, valueOutputChallenge);
    // transfer the rest to client
    uint balance = tokenContract.balanceOf(address(this));
    tokenContract.transfer(client, balance);
    currentState = state.FinishedProviderWonOutputHashChallenge;
  }

  /// @notice In case of a memory challenge, this function should be called
  /// so that the contract will write writeChallenge.initialHash in the
  /// position pointed by writeChallenge.position.
  function insertionForMemoryWriteChallenge() public {
    require(msg.sender == provider);
    require(currentState == state.WaitInsertionForMemoryChallenge);
    require(mm.currentState == MMLib.state.Reading);
    bytes8 word1 = bytes8(writeChallenge.initialHash);
    bytes8 word2 = bytes8(writeChallenge.initialHash << 64);
    bytes8 word3 = bytes8(writeChallenge.initialHash << 128);
    bytes8 word4 = bytes8(writeChallenge.initialHash << 192);
    mm.write(writeChallenge.position, word1);
    mm.write(writeChallenge.position + 8, word2);
    mm.write(writeChallenge.position + 16, word3);
    mm.write(writeChallenge.position + 24, word4);
    timeOfLastMove = now;
    currentState = state.WaitMemoryWriteChallenge;
  }

  /// @notice After the provider having updated the hash of mm to
  /// account for the memory insertion done in insertionForMemoryWriteChallenge,
  /// the provider calls this function to prove that he was correct in the
  /// memory insertion challenge.
  function settleMemoryWriteChallenge() public {
    require(msg.sender == provider);
    require(currentState == state.WaitMemoryWriteChallenge);
    require(mm.currentState == MMLib.state.Finished);
    require(mm.newHash == writeChallenge.finalHash);
    tokenContract.transfer(provider,
                           2 * parameters.deposit + auction.contractedPrice);
    currentState = state.FinishedProviderWonMemoryWriteChallenge;
  }

  /// @notice In case one of the parties wins the partition challenge by
  /// timeout, then he or she can call this function to claim victory in
  /// the hireCPU contract as well.
  function winByPartitionTimeout() public {
    require(currentState == state.WaitPartitionDispute);
    if (partition.currentState == PartitionLib.state.ChallengerWon) {
      tokenContract.transfer(client,
                             2 * parameters.deposit + auction.contractedPrice);
      currentState = state.FinishedPartitionProviderTimeout;
    }
    if (partition.currentState == PartitionLib.state.ClaimerWon) {
      tokenContract.transfer(provider,
                             2 * parameters.deposit + auction.contractedPrice);
      currentState = state.FinishedPartitionClientTimeout;
    }
  }

  /// @notice After the partition challenge has lead to a divergence in the hash
  /// within one time step, anyone can start a mechine run challenge to decide
  /// whether the provider was correct about that particular step transition.
  /// This function call solely instantiate a memory manager, so the the
  /// provider can fill the appropriate addresses that will be read by the
  /// machine.
  function startMachineRunChallenge() public {
    require(currentState == state.WaitPartitionDispute);
    require(partition.currentState == PartitionLib.state.DivergenceFound);
    uint divergenceTime = partition.divergenceTime;
    runChallenge.hashBeforeDivergence
      = partition.timeHash[divergenceTime];
    runChallenge.hashAfterDivergence
      = partition.timeHash[divergenceTime + 1];
    mm.init(provider, address(this), runChallenge.hashBeforeDivergence);
    timeOfLastMove = now;
    currentState = state.WaitForMachineToRun;
  }

  /// @notice After having filled the memory manager with the necessary data,
  /// the provider calls this function to instantiate the machine and perform
  /// one step on it. The machine will write to memory in the process and the
  /// provider will be expected to update the memory hash accordingly.
  function continueMachineRunChallenge() public {
    require(msg.sender == provider);
    require(currentState == state.WaitForMachineToRun);
    mm.client = subleq.getAddress();
    subleq.step();
    timeOfLastMove = now;
    currentState = state.WaitToFinishMachineRunChallenge;
  }

  /// @notice After having updated to memory to account for the addresses
  /// that were written by the machine, the provider now calls this function
  /// to settle the challenge in his favour.
  function settleMachineRunChallenge() public {
    require(msg.sender == provider);
    require(currentState == state.WaitToFinishMachineRunChallenge);
    require(mm.currentState == MMLib.state.Finished);
    require(mm.newHash != runChallenge.hashAfterDivergence);
    tokenContract.transfer(client,
                           2 * parameters.deposit + auction.contractedPrice);
    currentState = state.FinishedProviderWonMachineRunChallenge;
  }

  // this part of the code refers to a disagreement on the transfer of data

  /// @notice Client denies that the data from provider was available
  // off-chain and this starts the "unacknowledge" challenges
  function denyTransfer() public {
    require(msg.sender == client);
    require(currentState == state.WaitTransferReceipt);
    timeOfLastMove = now;
    currentState = state.WaitDecryptedSolutionHash;
  }

  /// @notice Having noticed that the Client claimed that the data was not
  /// available off-chain, the provider sends the hash for the unencrypted
  /// outputs in order to prove that he has done the calculations without
  /// providing the client with their contents.
  /// @param _hashOutputList the hash of the memory containing
  /// the unencrypted outputs.
  function sendDecryptedSolution(bytes32 _hashOutputList) public
  {
    require(msg.sender == provider);
    require(currentState == state.WaitDecryptedSolutionHash);
    unacknowledged.hashOutputList = _hashOutputList;
    timeOfLastMove = now;
    currentState = state.WaitUnacknowledgedSampleSeed;
  }

  /// @notice The client has not acknowledged the receipt of the output data
  /// she must now give one random seed to verify whether the provider
  /// has indeed made that specific calculation.
  /// @param _seed the index of the seed to be sampled.
  function giveUnacknowledgedSampleSeed (uint64 _seed) public {
    require(msg.sender == client);
    require(currentState == state.WaitUnacknowledgedSampleSeed);
    require(_seed < computation.seedNumber);
    unacknowledged.seed = _seed;
    timeOfLastMove = now;
    currentState = state.WaitUnacknowledgedExplanation;
  }

  /// @notice Provider sends all the hashes that are necessary to prove
  /// that his calculations are correct for the controversial hash
  function giveUnacknowledgedExplanation
    ( bytes32 _clientMachineInitialHash,
      bytes32 _final1HashOfClientMachine,
      bytes32 _final2HashOfClientMachine,
      bytes32 _final3HashOfClientMachine,
      bytes32 _hashSelectedOutput
      ) public {
    require(msg.sender == provider);
    require(currentState == state.WaitUnacknowledgedExplanation);
    // store the client machine initial hash
    unacknowledged.clientMachineInitialHash = _clientMachineInitialHash;
    // assemble client machine final hash
    unacknowledged.hashSelectedOutput = _hashSelectedOutput;
    bytes32 machine = keccak256
      ( _final1HashOfClientMachine,
        _final2HashOfClientMachine
        );
    bytes32 inputOutput = keccak256
      ( _final3HashOfClientMachine,
        unacknowledged.hashSelectedOutput
        );
    unacknowledged.clientMachineFinalHash = keccak256(machine, inputOutput);
    timeOfLastMove = now;
    currentState = state.WaitUnacknowledgedChallenge;
  }

  /// @notice Client has not acknowledged the receipt of the output data.
  /// After sampling a sampleSeed for test she received the explanation
  /// from the provider, she now must decide what part of the calculation
  /// she wants to challenge
  /// @param _challenge the type of challenge she will present with the
  /// choices:
  ///  - outputHash: dispute that unacknowledged.hashOutputList
  ///    points to unacknowledged.hashSelectedOutput at position
  ///    unacknowledged.seed
  ///  - seedInsertion: dispute that inserting the unacknowledged.seed into the
  ///    client machine yields unacknowledged.clientMachineInitialHash
  ///    (needs payment)
  ///  - clientMachineRun: dispute that running the machine from
  ///    unacknowledged.clientMachineInitialHash will give finish with
  ///    unacknowledged.clientMachineFinalHash (needs payment)
  function postUnacknowledgedChallenge(challenge _challenge) public {
    require(msg.sender == client);
    require(currentState == state.WaitUnacknowledgedChallenge);
    if (_challenge == challenge.outputHash) {
      valueOutputChallenge = parameters.deposit
        + auction.contractedPrice/2;
      mm.init(provider, address(this), unacknowledged.hashOutputList);
      currentState = state.WaitOutputHashChallenge;
    }
    if (_challenge == challenge.seedInsertion) {
      tokenContract.transferFrom(client, address(this), parameters.deposit);
      writeChallenge.position = computation.seedAddress;
      // care for the endianness of the machine
      writeChallenge.initialHash = bytes32(uint256(unacknowledged.seed));
      writeChallenge.finalHash = unacknowledged.clientMachineInitialHash;
      mm.init(provider, address(this), computation.preparationHash);
      currentState = state.WaitInsertionForMemoryChallenge;
    }
    if (_challenge == challenge.clientMachineRun) {
      tokenContract.transferFrom(client, address(this), parameters.deposit);
      partition.init(client, provider, unacknowledged.clientMachineInitialHash,
                     unacknowledged.clientMachineFinalHash, computation.time,
                     10, parameters.roundDuration);
      currentState = state.WaitPartitionDispute;
    }
    timeOfLastMove = now;
  }

  /// @notice Any party can claim victory if the other has lost the deadline
  /// for some of the steps in the protocol.
  function claimVictoryByDeadline() public {
    uint balance;
    if (msg.sender == client) {
      if ((currentState == state.WaitAcknowledgedKey)
          || (currentState == state.WaitAcknowledgedExplanation)
          || (currentState == state.WaitOutputHashChallenge)
          || (currentState == state.WaitInsertionForMemoryChallenge)
          || (currentState == state.WaitMemoryWriteChallenge)
          || (currentState == state.WaitForMachineToRun)
          || (currentState == state.WaitToFinishMachineRunChallenge)
          || (currentState == state.WaitDecryptedSolutionHash)
          || (currentState == state.WaitUnacknowledgedExplanation)) {
        if (now > timeOfLastMove + parameters.roundDuration) {
          balance = tokenContract.balanceOf(address(this));
          tokenContract.transfer(client, balance);
          currentState = state.FinishedProviderTimeout;
          emit ChallengeEnded(currentState);
        }
      }
      if ((currentState == state.WaitSolution)
          && (now > timeOfLastMove + parameters.jobDuration)) {
        balance = tokenContract.balanceOf(address(this));
        tokenContract.transfer(client, balance);
        currentState = state.FinishedProviderTimeout;
        emit ChallengeEnded(currentState);
      }
    }
    if (msg.sender == provider) {
      if ((currentState == state.WaitTransferReceipt)
          || (currentState == state.WaitAcknowledgedApproval)
          || (currentState == state.WaitAcknowledgedChallenge)
          || (currentState == state.WaitUnacknowledgedSampleSeed)
          || (currentState == state.WaitUnacknowledgedChallenge)) {
        if (now > timeOfLastMove + parameters.roundDuration) {
          balance = tokenContract.balanceOf(address(this));
          tokenContract.transfer(provider, balance);
          currentState = state.FinishedClientTimeout;
          emit ChallengeEnded(currentState);
        }
      }
    }
  }

  // to kill the contract and receive refunds
  function killContract() public {
    require((currentState == state.FinishedNoBidder)
            || (currentState == state.FinishedSmooth)
            || (currentState == state.FinishedProviderWonOutputHashChallenge)
            || (currentState == state.FinishedProviderWonMemoryWriteChallenge)
            || (currentState == state.FinishedProviderWonMachineRunChallenge)
            || (currentState == state.FinishedPartitionProviderTimeout)
            || (currentState == state.FinishedPartitionClientTimeout)
            || (currentState == state.FinishedProviderTimeout)
            || (currentState == state.FinishedClientTimeout));
    uint balance = tokenContract.balanceOf(address(this));
    tokenContract.transfer(client, balance);
    selfdestruct(client);
  }
}

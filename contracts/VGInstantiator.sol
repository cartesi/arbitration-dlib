// @title Verification game instantiator
pragma solidity ^0.4.23;

import "./Decorated.sol";
import "./Instantiator.sol";
import "./VGInterface.sol";
import "./PartitionInterface.sol";
import "./MMInterface.sol";
import "./MachineInterface.sol";
import "./lib/bokkypoobah/Token.sol";

contract VGInstantiator is Decorated, VGInterface
{
  using SafeMath for uint;

  Token private tokenContract; // address of Themis ERC20 contract
  PartitionInterface private partition;
  MMInterface private mm;

  struct VGCtx
  {
    address challenger; // the two parties involved in each instance
    address claimer;
    uint valueXYZ; // the value given to the winner in XYZ
    uint challengerPriceXYZ; // price if someone wants to buy from challenger
    uint challengerDoubleDown; // amount added by challenger to instance
    uint claimerPriceXYZ; // price if someone wants to buy from claimer
    uint claimerDoubleDown; // amount added by claimer to instance
    uint salesDuration; // time interval to sell the instance
    uint roundDuration; // time interval to interact with this contract
    MachineInterface machine; // the machine which will run the challenge
    bytes32 initialHash; // hash of machine memory that both aggree uppon
    bytes32 claimerFinalHash; // hash claimer commited for machine after running
    uint finalTime; // the time for which the machine should run
    uint timeOfLastMove; // last time someone made a move with deadline
    uint32 mmInstance; // the instance of the memory that was given to this game
    uint32 partitionInstance; // the partition instance given to this game
    bytes32 hashBeforeDivergence;
    bytes32 hashAfterDivergence;
    state currentState;
  }

  mapping(uint32 => VGCtx) private instance;

  // These are the possible states and transitions of the contract.
  //
  //               +---+
  //               |   |
  //               +---+
  //                 |
  //                 | instantiate
  //                 v                     | setChallengerPrice
  //               +----------+            | setClaimerPrice
  //               | WaitSale |------------| buyInstanceFromChallenger
  //               +----------+            | buyInstanceFromClaimer
  //                 |
  //                 | finishSalePhase
  //                 v
  //               +----------------+  winByPartitionTimeout
  //   +-----------| WaitPartition  |------------------------+
  //   |           +----------------+                        |
  //   |                         |                           |
  //   | winByPartitionTimeout   | startMachineRunChallenge  |
  //   |                         v                           |
  //   |           +-----------------------+                 |
  //   | +---------| WaitMemoryProveValues |                 |
  //   | |         +-----------------------+                 |
  //   | |                       |                           |
  //   | |claimVictoryByDeadline | settleVerificationGame    |
  //   v v                       |                           v
  // +--------------------+      |        +-----------------------+
  // | FinishedClaimerWon |      +------->| FinishedChallengerWon |
  // +--------------------+               +-----------------------+
  //

  event VGCreated(uint32 _index, address _challenger, address _claimer,
                  uint _valueXYZ, uint _roundDuration, address _machineAddress,
                  bytes32 _initialHash, bytes32 _claimerFinalHash,
                  uint _finalTime, uint32 _partitionInstance);
  event SetPrice(bool _isChallenger, uint32 _index, uint _value,
                 uint _doubleDown);
  event StartChallenge(uint32 _index, uint32 _partitionInstance);
  event PartitionDivergenceFound(uint32 _index, uint32 _mmInstance);
  event MemoryWriten(uint32 _index);
  event VGFinished(state _finalState);

  constructor(address _tokenContractAddress,
              address _partitionInstantiatorAddress,
              address _mmInstantiatorAddress) public {
    tokenContract = Token(_tokenContractAddress);
    partition = PartitionInterface(_partitionInstantiatorAddress);
    mm = MMInterface(_mmInstantiatorAddress);
  }

  function instantiate(address _challenger, address _claimer, uint _valueXYZ,
                       uint _roundDuration, uint _salesDuration,
                       address _machineAddress, bytes32 _initialHash,
                       bytes32 _claimerFinalHash, uint _finalTime)
    public returns (uint32)
  {
    require(tokenContract.transferFrom(msg.sender, address(this), _valueXYZ));
    require(_finalTime > 0);
    instance[currentIndex].challenger = _challenger;
    instance[currentIndex].claimer = _claimer;
    instance[currentIndex].valueXYZ = _valueXYZ;
    instance[currentIndex].challengerPriceXYZ = _valueXYZ;
    instance[currentIndex].challengerDoubleDown = 0;
    instance[currentIndex].claimerPriceXYZ = _valueXYZ;
    instance[currentIndex].claimerDoubleDown = 0;
    instance[currentIndex].salesDuration = _salesDuration;
    instance[currentIndex].roundDuration = _roundDuration;
    instance[currentIndex].machine = MachineInterface(_machineAddress);
    instance[currentIndex].initialHash = _initialHash;
    instance[currentIndex].claimerFinalHash = _claimerFinalHash;
    instance[currentIndex].finalTime = _finalTime;
    instance[currentIndex].timeOfLastMove = now;
    instance[currentIndex].currentState = state.WaitSale;
    emit VGCreated(currentIndex, _challenger, _claimer, _valueXYZ,
                   _roundDuration, _machineAddress, _initialHash,
                   _claimerFinalHash, _finalTime,
                   instance[currentIndex].partitionInstance);
    currentIndex++;
    return(currentIndex - 1);
  }

  /// @notice Set a new price for the instance and possibly increase its value
  /// During sale phase, anyone can increase the value of an instance
  /// this can be used to signal to buyers that the player is convinced of the
  /// victory and incentivise them to pre-execute the verification off-chain.
  function setChallengerPrice(uint32 _index, uint _newPrice,
                              uint _doubleDown) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].challenger)
  {
    require(instance[_index].currentState == state.WaitSale);
    require(tokenContract.transferFrom(msg.sender, address(this), _doubleDown));
    instance[_index].challengerPriceXYZ = _newPrice;
    instance[_index].valueXYZ += _doubleDown;
    instance[_index].challengerDoubleDown += _doubleDown;
    emit SetPrice(true, _index, _newPrice, _doubleDown);
  }

  function setClaimerPrice(uint32 _index, uint _newPrice,
                           uint _doubleDown) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].claimer)
  {
    require(instance[_index].currentState == state.WaitSale);
    require(tokenContract.transferFrom(msg.sender, address(this), _doubleDown));
    instance[_index].claimerPriceXYZ = _newPrice;
    instance[_index].valueXYZ += _doubleDown;
    instance[_index].claimerDoubleDown += _doubleDown;
    emit SetPrice(false, _index, _newPrice, _doubleDown);
  }

  /// @notice During sale phase, anyone can buy this instance from challenger
  function buyInstanceFromChallenger(uint32 _index) public
    onlyInstantiated(_index)
  {
    require(instance[_index].currentState == state.WaitSale);
    require(tokenContract.transferFrom(msg.sender, address(this),
                                       instance[_index].challengerPriceXYZ));
    require(tokenContract.transfer(instance[_index].challenger,
                                   instance[_index].challengerPriceXYZ));
    instance[_index].challenger = msg.sender;
    instance[_index].challengerPriceXYZ = instance[_index].valueXYZ;
  }

  /// @notice During sale phase, anyone can buy this instance from claimer
  function buyInstanceFromClaimer(uint32 _index) public
    onlyInstantiated(_index)
  {
    require(instance[_index].currentState == state.WaitSale);
    require(tokenContract.transferFrom(msg.sender, address(this),
                                       instance[_index].claimerPriceXYZ));
    require(tokenContract.transfer(instance[_index].claimer,
                                   instance[_index].claimerPriceXYZ));
    instance[_index].claimer = msg.sender;
    instance[_index].claimerPriceXYZ = instance[_index].valueXYZ;
  }

  /// @notice After the sales duration, the sale phase can be
  /// finished by anyone.
  function finishSalePhase(uint32 _index) public
    onlyInstantiated(_index)
    onlyAfter(instance[_index].timeOfLastMove + instance[_index].salesDuration)
  {
    require(instance[_index].currentState == state.WaitSale);
    instance[_index].timeOfLastMove = now;
    instance[_index].partitionInstance =
      partition.instantiate(instance[_index].challenger,
                            instance[_index].claimer,
                            instance[_index].initialHash,
                            instance[_index].claimerFinalHash,
                            instance[_index].finalTime,
                            10,
                            instance[_index].roundDuration);
    delete instance[_index].challengerPriceXYZ;
    delete instance[_index].claimerPriceXYZ;
    delete instance[_index].salesDuration;
    instance[_index].currentState = state.WaitPartition;
    emit StartChallenge(_index, instance[_index].partitionInstance);
  }

  /// @notice In case one of the parties wins the partition challenge by
  /// timeout, then he or she can call this function to claim victory in
  /// the hireCPU contract as well.
  function winByPartitionTimeout(uint32 _index) public
    onlyInstantiated(_index)
  {
    require(instance[_index].currentState == state.WaitPartition);
    uint32 partitionIndex = instance[_index].partitionInstance;
    if (partition.stateIsChallengerWon(partitionIndex))
      { challengerWins(_index); return; }
    if (partition.stateIsClaimerWon(partitionIndex))
      { claimerWins(_index); return; }
    require(false);
  }

  /// @notice After the partition challenge has lead to a divergence in the hash
  /// within one time step, anyone can start a mechine run challenge to decide
  /// whether the claimer was correct about that particular step transition.
  /// This function call solely instantiate a memory manager, so the
  /// provider must fill the appropriate addresses that will be read by the
  /// machine.
  function startMachineRunChallenge(uint32 _index) public
    onlyInstantiated(_index)
  {
    require(instance[_index].currentState == state.WaitPartition);
    require(partition
            .stateIsDivergenceFound(instance[_index].partitionInstance));
    uint32 partitionIndex = instance[_index].partitionInstance;
    uint divergenceTime = partition.divergenceTime(partitionIndex);
    instance[_index].hashBeforeDivergence
      = partition.timeHash(partitionIndex, divergenceTime);
    instance[_index].hashAfterDivergence
      = partition.timeHash(partitionIndex, divergenceTime + 1);
    instance[_index].mmInstance =
      mm.instantiate(instance[_index].challenger,
                     instance[_index].machine,
                     instance[_index].hashBeforeDivergence);
    // !!!!!!!!! should call delete in partitionInstance !!!!!!!!!
    delete instance[_index].partitionInstance;
    instance[_index].timeOfLastMove = now;
    instance[_index].currentState = state.WaitMemoryProveValues;
    emit PartitionDivergenceFound(_index, instance[_index].mmInstance);
  }

  /// @notice After having filled the memory manager with the necessary data,
  /// the provider calls this function to instantiate the machine and perform
  /// one step on it. The machine will write to memory now. Later, the
  /// provider will be expected to update the memory hash accordingly.
  function settleVerificationGame(uint32 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].challenger)
  {
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    uint32 mmIndex = instance[_index].mmInstance;
    require(mm.stateIsWaitingReplay(mmIndex));
    instance[_index].machine.step(address(mm), mmIndex);
    require(mm.stateIsFinishedReplay(mmIndex));
    require(mm.newHash(mmIndex) != instance[_index].hashAfterDivergence);
    challengerWins(_index);
  }

  /// @notice Claimer can claim victory if challenger has lost the deadline
  /// for some of the steps in the protocol.
  function claimVictoryByDeadline(uint32 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].claimer)
    onlyAfter(instance[_index].timeOfLastMove + instance[_index].roundDuration)
  {
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    claimerWins(_index);
  }

  function challengerWins(uint32 _index) private
    onlyInstantiated(_index)
  {
      tokenContract.transfer(instance[_index].challenger,
                             instance[_index].valueXYZ);
      clearInstance(_index);
      instance[_index].currentState = state.FinishedChallengerWon;
      emit VGFinished(instance[_index].currentState);
  }

  function claimerWins(uint32 _index) private
    onlyInstantiated(_index)
  {
      tokenContract.transfer(instance[_index].claimer,
                             instance[_index].valueXYZ);
      clearInstance(_index);
      instance[_index].currentState = state.FinishedClaimerWon;
      emit VGFinished(instance[_index].currentState);
  }

  function clearInstance(uint32 _index) internal
    onlyInstantiated(_index)
  {
    delete instance[_index].challenger;
    delete instance[_index].claimer;
    delete instance[_index].valueXYZ;
    delete instance[_index].roundDuration;
    delete instance[_index].machine;
    delete instance[_index].initialHash;
    delete instance[_index].claimerFinalHash;
    delete instance[_index].finalTime;
    delete instance[_index].timeOfLastMove;
    // !!!!!!!!! should call delete in mmInstance !!!!!!!!!
    delete instance[_index].mmInstance;
    delete instance[_index].hashBeforeDivergence;
    delete instance[_index].hashAfterDivergence;
  }

  // state getters

  function stateIsWaitSale(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitSale; }

  function stateIsWaitPartition(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitPartition; }

  function stateIsWaitMemoryProveValues(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitMemoryProveValues; }

  function stateIsFinishedClaimerWon(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedClaimerWon; }

  function stateIsFinishedChallengerWon(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedClaimerWon; }
}

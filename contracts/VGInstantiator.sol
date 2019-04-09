// @title Verification game instantiator
pragma solidity 0.5;

import "./Decorated.sol";
import "./Instantiator.sol";
import "./VGInterface.sol";
import "./PartitionInterface.sol";
import "./MMInterface.sol";
import "./MachineInterface.sol";

contract VGInstantiator is Decorated, VGInterface
{
  //  using SafeMath for uint;

  PartitionInterface private partition;
  MMInterface private mm;

  struct VGCtx
  {
    address challenger; // the two parties involved in each instance
    address claimer;
    uint roundDuration; // time interval to interact with this contract
    MachineInterface machine; // the machine which will run the challenge
    bytes32 initialHash; // hash of machine memory that both aggree uppon
    bytes32 claimerFinalHash; // hash claimer commited for machine after running
    uint finalTime; // the time for which the machine should run
    uint timeOfLastMove; // last time someone made a move with deadline
    uint256 mmInstance; // the instance of the memory that was given to this game
    uint256 partitionInstance; // the partition instance given to this game
    uint divergenceTime; // the time in which the divergence happened
    bytes32 hashBeforeDivergence; // hash aggreed right before divergence
    bytes32 hashAfterDivergence; // hash in conflict right after divergence
    state currentState;
  }

  mapping(uint256 => VGCtx) private instance;

  // These are the possible states and transitions of the contract.
  //
  //               +---+
  //               |   |
  //               +---+
  //                 |
  //                 | instantiate
  //                 v
  //               +----------------+  winByPartitionTimeout
  //   +-----------| WaitPartition  |------------------------+
  //   |           +----------------+                        |
  //   |                         |                           |
  //   | winByPartitionTimeout   | startMachineRunChallenge  |
  //   |                         v                           |
  //   |           +-----------------------+                 |
  //   | +---------| WaitMemoryProveValues |---------------+ |
  //   | |         +-----------------------+               | |
  //   | |                                                 | |
  //   | |claimVictoryByDeadline   settleVerificationGame  | |
  //   v v                                                 v v
  // +--------------------+               +-----------------------+
  // | FinishedClaimerWon |               | FinishedChallengerWon |
  // +--------------------+               +-----------------------+
  //

  event VGCreated(uint256 _index, address _challenger, address _claimer,
                  uint _roundDuration, address _machineAddress,
                  bytes32 _initialHash, bytes32 _claimerFinalHash,
                  uint _finalTime, uint256 _partitionInstance);
  event PartitionDivergenceFound(uint256 _index, uint256 _mmInstance);
  event MemoryWriten(uint256 _index);
  event VGFinished(state _finalState);

  constructor(address _partitionInstantiatorAddress,
              address _mmInstantiatorAddress) public {
    partition = PartitionInterface(_partitionInstantiatorAddress);
    mm = MMInterface(_mmInstantiatorAddress);
  }

  function instantiate(address _challenger, address _claimer,
                       uint _roundDuration, address _machineAddress,
                       bytes32 _initialHash, bytes32 _claimerFinalHash,
                       uint _finalTime)
    public returns (uint256)
  {
    require(_finalTime > 0);
    instance[currentIndex].challenger = _challenger;
    instance[currentIndex].claimer = _claimer;
    instance[currentIndex].roundDuration = _roundDuration;
    instance[currentIndex].machine = MachineInterface(_machineAddress);
    instance[currentIndex].initialHash = _initialHash;
    instance[currentIndex].claimerFinalHash = _claimerFinalHash;
    instance[currentIndex].finalTime = _finalTime;
    instance[currentIndex].timeOfLastMove = now;
    instance[currentIndex].partitionInstance =
      partition.instantiate(_challenger,
                            _claimer,
                            _initialHash,
                            _claimerFinalHash,
                            _finalTime,
                            10,
                            _roundDuration);
    instance[currentIndex].currentState = state.WaitPartition;
    emit VGCreated(currentIndex, _challenger, _claimer,
                   _roundDuration, _machineAddress, _initialHash,
                   _claimerFinalHash, _finalTime,
                   instance[currentIndex].partitionInstance);

    active[currentIndex] = true;
    return(currentIndex++);
  }

  /// @notice In case one of the parties wins the partition challenge by
  /// timeout, then he or she can call this function to claim victory in
  /// the hireCPU contract as well.
  function winByPartitionTimeout(uint256 _index) public
    onlyInstantiated(_index)
  {
    require(instance[_index].currentState == state.WaitPartition);
    uint256 partitionIndex = instance[_index].partitionInstance;
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
  function startMachineRunChallenge(uint256 _index) public
    onlyInstantiated(_index)
    increasesNonce(_index)
  {
    require(instance[_index].currentState == state.WaitPartition);
    require(partition
            .stateIsDivergenceFound(instance[_index].partitionInstance));
    uint256 partitionIndex = instance[_index].partitionInstance;
    uint divergenceTime = partition.divergenceTime(partitionIndex);
    instance[_index].divergenceTime = divergenceTime;
    instance[_index].hashBeforeDivergence
      = partition.timeHash(partitionIndex, divergenceTime);
    instance[_index].hashAfterDivergence
      = partition.timeHash(partitionIndex, divergenceTime + 1);
    instance[_index].mmInstance =
      mm.instantiate(instance[_index].challenger,
                     address(instance[_index].machine),
                     instance[_index].hashBeforeDivergence);
    // !!!!!!!!! should call clear in partitionInstance !!!!!!!!!
    delete instance[_index].partitionInstance;
    instance[_index].timeOfLastMove = now;
    instance[_index].currentState = state.WaitMemoryProveValues;
    emit PartitionDivergenceFound(_index, instance[_index].mmInstance);
  }

  /// @notice After having filled the memory manager with the necessary data,
  /// the provider calls this function to instantiate the machine and perform
  /// one step on it. The machine will write to memory now. Later, the
  /// provider will be expected to update the memory hash accordingly.
  function settleVerificationGame(uint256 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].challenger)
  {
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    uint256 mmIndex = instance[_index].mmInstance;
    require(mm.stateIsWaitingReplay(mmIndex));
    instance[_index].machine.step(address(mm), mmIndex);
    require(mm.stateIsFinishedReplay(mmIndex));
    require(mm.newHash(mmIndex) != instance[_index].hashAfterDivergence);
    challengerWins(_index);
  }

  /// @notice Claimer can claim victory if challenger has lost the deadline
  /// for some of the steps in the protocol.
  function claimVictoryByTime(uint256 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].claimer)
    onlyAfter(instance[_index].timeOfLastMove + instance[_index].roundDuration)
  {
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    claimerWins(_index);
  }

  function challengerWins(uint256 _index) private
    onlyInstantiated(_index)
  {
      clearInstance(_index);
      instance[_index].currentState = state.FinishedChallengerWon;
      emit VGFinished(instance[_index].currentState);
  }

  function claimerWins(uint256 _index) private
    onlyInstantiated(_index)
  {
      clearInstance(_index);
      instance[_index].currentState = state.FinishedClaimerWon;
      emit VGFinished(instance[_index].currentState);
  }

  function clearInstance(uint256 _index) internal
    onlyInstantiated(_index)
  {
    delete instance[_index].challenger;
    delete instance[_index].claimer;
    delete instance[_index].roundDuration;
    delete instance[_index].machine;
    delete instance[_index].initialHash;
    delete instance[_index].claimerFinalHash;
    delete instance[_index].finalTime;
    delete instance[_index].timeOfLastMove;
    // !!!!!!!!! should call clear in mmInstance !!!!!!!!!
    delete instance[_index].mmInstance;
    delete instance[_index].divergenceTime;
    delete instance[_index].hashBeforeDivergence;
    delete instance[_index].hashAfterDivergence;
    deactivate(_index);
  }

  // state getters

  function getState(uint256 _index) public view
    onlyInstantiated(_index)
    returns ( address _challenger,
              address _claimer,
              MachineInterface _machine,
              bytes32 _initialHash,
              bytes32 _claimerFinalHash,
              bytes32 _hashBeforeDivergence,
              bytes32 _hashAfterDivergence,
              bytes32 _currentState,
              uint[6] memory _uintValues)
  {
    VGCtx memory i = instance[_index];

    uint[6] memory uintValues =
      [i.roundDuration,
       i.finalTime,
       i.timeOfLastMove,
       i.mmInstance,
       i.partitionInstance,
       i.divergenceTime
       ];

    // we have to duplicate the code for getCurrentState because of
    // "stack too deep"
    bytes32 currentState;
    if (i.currentState == state.WaitPartition)
      { currentState = "WaitPartition"; }
    if (i.currentState == state.WaitMemoryProveValues)
      { currentState = "WaitMemoryProveValues"; }
    if (i.currentState == state.FinishedClaimerWon)
      { currentState = "FinishClaimerWon"; }
    if (i.currentState == state.FinishedChallengerWon)
      { currentState = "FinishedChallengerWon"; }

    return
      (
       i.challenger,
       i.claimer,
       i.machine,
       i.initialHash,
       i.claimerFinalHash,
       i.hashBeforeDivergence,
       i.hashAfterDivergence,
       currentState,
       uintValues
       );
  }

  function isConcerned(uint256 _index, address _user) public view returns(bool)
  {
    return ((instance[_index].challenger == _user)
            || (instance[_index].claimer == _user));
  }

  function getSubInstances(uint256 _index)
    public view returns(address[] memory _addresses,
                        uint256[] memory _indices)
  {
    address[] memory a;
    uint256[] memory i;
    if (instance[_index].currentState == state.WaitPartition)
      {
        a = new address[](1);
        i = new uint256[](1);
        a[0] = address(partition);
        i[0] = instance[_index].partitionInstance;
        return (a, i);
      }
    if (instance[_index].currentState == state.WaitMemoryProveValues)
      {
        a = new address[](1);
        i = new uint256[](1);
        a[0] = address(mm);
        i[0] = instance[_index].mmInstance;
        return (a, i);
      }
    a = new address[](0);
    i = new uint256[](0);
    return (a, i);
  }

  function getCurrentState(uint256 _index) public view
    onlyInstantiated(_index)
    returns (bytes32)
  {
    if (instance[_index].currentState == state.WaitPartition)
      { return "WaitPartition"; }
    if (instance[_index].currentState == state.WaitMemoryProveValues)
      { return "WaitMemoryProveValues"; }
    if (instance[_index].currentState == state.FinishedClaimerWon)
      { return "FinishClaimerWon"; }
    if (instance[_index].currentState == state.FinishedChallengerWon)
      { return "FinishedChallengerWon"; }
    require(false, "Unrecognized state");
  }

  // remove these functions and change tests accordingly
  /* function stateIsWaitPartition(uint256 _index) public view */
  /*   onlyInstantiated(_index) */
  /*   returns(bool) */
  /* { return instance[_index].currentState == state.WaitPartition; } */

  /* function stateIsWaitMemoryProveValues(uint256 _index) public view */
  /*   onlyInstantiated(_index) */
  /*   returns(bool) */
  /* { return instance[_index].currentState == state.WaitMemoryProveValues; } */

  function stateIsFinishedClaimerWon(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedClaimerWon; }

  function stateIsFinishedChallengerWon(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedChallengerWon; }
}

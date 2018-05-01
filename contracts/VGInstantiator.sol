/// @title Verification game instantiator
pragma solidity ^0.4.0;

import "./PartitionInterface.sol";
import "./MMInterface.sol";
import "./SubleqInterface.sol";
import "./lib/bokkypoobah/Token.sol";

contract VGInstantiator is SubleqInterface
{
  using SafeMath for uint;

  uint32 private currentIndex = 0;

  Token private tokenContract; // address of Themis ERC20 contract
  PartitionInterface private partition;
  MMInterface private mm;

  mapping (address => uint) private balanceOf;

  enum state { WaitPartition, WaitMemoryProveValues,
               FinishedClaimerWon, FinishedChallengerWon }

  // IMPLEMENT GARBAGE COLLECTOR AFTER AN INSTACE IS FINISHED!
  struct VGCtx
  {
    address challenger; // the two parties involved in each instance
    address claimer;
    uint valueETH; // the value given to the winner in Ether
    uint valueXYZ; // the value given to the winner in XYZ
    uint roundDuration; // time interval to interact with this contract
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

  event VGCreated(uint32 _index, address _challenger, address _claimer,
                  uint _valueETH, uint _valueXYZ, uint _roundDuration,
                  bytes32 _initialHash, bytes32 _claimerFinalHash,
                  uint _finalTime, uint32 _partitionInstance);
  event PartitionDivergenceFound();
  event MachineStepGiven();
  event VGFinished(state);

  function VGInstantiator(address _tokenContractAddress,
                          address _partitionInstantiatorAddress,
                          address _mmInstantiatorAddress) public {
    tokenContract = Token(_tokenContractAddress);
    partition = PartitionInterface(_partitionInstantiatorAddress);
    mm = MMInterface(_mmInstantiatorAddress);
  }

  function instantiate(address _challenger, address _claimer, uint _valueETH,
                       uint _valueXYZ, uint _roundDuration,
                       bytes32 _initialHash, bytes32 _claimerFinalHash,
                       uint _finalTime) public payable
    returns (uint32)
  {
    require(msg.value >= _valueETH);
    require(tokenContract.transferFrom(msg.sender, address(this), _valueXYZ));
    require(_finalTime > 0);
    instance[currentIndex].challenger = _challenger;
    instance[currentIndex].claimer = _claimer;
    instance[currentIndex].valueETH = _valueETH;
    instance[currentIndex].valueXYZ = _valueXYZ;
    instance[currentIndex].roundDuration = _roundDuration;
    instance[currentIndex].initialHash = _initialHash;
    instance[currentIndex].claimerFinalHash = _claimerFinalHash;
    instance[currentIndex].finalTime = _finalTime;
    instance[currentIndex].partitionInstance =
      partition.instantiate(_challenger, _claimer, _initialHash,
                            _claimerFinalHash, _finalTime, 10, _roundDuration);
    instance[currentIndex].timeOfLastMove = now;
    instance[currentIndex].currentState = state.WaitPartition;
    emit VGCreated(currentIndex, _challenger, _claimer, _valueETH, _valueXYZ,
                   _roundDuration, _initialHash, _claimerFinalHash, _finalTime,
                   instance[currentIndex].partitionInstance);
    currentIndex++;
    return(currentIndex - 1);
  }

  /// @notice In case one of the parties wins the partition challenge by
  /// timeout, then he or she can call this function to claim victory in
  /// the hireCPU contract as well.
  function winByPartitionTimeout(uint32 _index) public {
    require(instance[_index].currentState == state.WaitPartition);
    uint32 partitionIndex = instance[_index].partitionInstance;
    if (partition.currentState(partitionIndex)
        == PartitionInterface.state.ChallengerWon)
      { challengerWins(_index); }
    if (partition.currentState(partitionIndex)
        == PartitionInterface.state.ClaimerWon)
      { claimerWins(_index); }
  }

  /// @notice After the partition challenge has lead to a divergence in the hash
  /// within one time step, anyone can start a mechine run challenge to decide
  /// whether the claimer was correct about that particular step transition.
  /// This function call solely instantiate a memory manager, so the the
  /// provider can fill the appropriate addresses that will be read by the
  /// machine.
  function startMachineRunChallenge(uint32 _index) public {
    require(instance[_index].currentState == state.WaitPartition);
    require(partition.currentState(_index)
            == PartitionInterface.state.DivergenceFound);
    uint32 partitionIndex = instance[_index].partitionInstance;
    uint divergenceTime = partition.divergenceTime(partitionIndex);
    instance[_index].hashBeforeDivergence
      = partition.timeHash(partitionIndex, divergenceTime);
    instance[_index].hashAfterDivergence
      = partition.timeHash(partitionIndex, divergenceTime + 1);
    instance[_index].mmInstance =
      mm.instantiate(instance[_index].challenger, address(this),
                     instance[_index].hashBeforeDivergence);
    instance[_index].timeOfLastMove = now;
    instance[_index].currentState = state.WaitMemoryProveValues;
  }

  /// @notice After having filled the memory manager with the necessary data,
  /// the provider calls this function to instantiate the machine and perform
  /// one step on it. The machine will write to memory and we will find out
  /// who is correct
  function settleVerificationGame(uint32 _index) public {
    require(msg.sender == instance[_index].challenger);
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    uint32 mmIndex = instance[_index].mmInstance;
    require(mm.currentState(mmIndex) == MMInterface.state.WaitingReplay);
    subleq.step(address(mm), mmIndex);
    require(mm.currentState(mmIndex) == MMInterface.state.FinishedReplay);
    require(mm.newHash(mmIndex) != instance[_index].hashAfterDivergence);
    challengerWins(_index);
  }

  /// @notice Claimer can claim victory if challenger has lost the deadline
  /// for some of the steps in the protocol.
  function claimVictoryByDeadline(uint32 _index) public
  {
    require(msg.sender == instance[_index].claimer);
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    require(now > instance[_index].timeOfLastMove
            + instance[_index].roundDuration);
    claimerWins(_index);
  }

  function challengerWins(uint32 _index) private
  {
      tokenContract.transfer(instance[_index].challenger,
                             instance[_index].valueXYZ);
      balanceOf[instance[_index].challenger].add(instance[_index].valueETH);
      instance[_index].currentState = state.FinishedChallengerWon;
  }

  function claimerWins(uint32 _index) private
  {
      tokenContract.transfer(instance[_index].claimer,
                             instance[_index].valueXYZ);
      balanceOf[instance[_index].claimer].add(instance[_index].valueETH);
      instance[_index].currentState = state.FinishedClaimerWon;
  }

  function withdraw() public {
    uint amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    msg.sender.transfer(amount);
  }
}

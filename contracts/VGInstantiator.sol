// @title Verification game instantiator
pragma solidity ^0.4.23;

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

  enum state { WaitSale, WaitPartition, WaitMemoryProveValues,
               FinishedClaimerWon, FinishedChallengerWon }

  // IMPLEMENT GARBAGE COLLECTOR AFTER AN INSTACE IS FINISHED!
  struct VGCtx
  {
    address challenger; // the two parties involved in each instance
    address claimer;
    uint valueXYZ; // the value given to the winner in XYZ
    uint challengerPriceXYZ; // price if someone wants to buy from challenger
    uint claimerPriceXYZ; // price if someone wants to buy from claimer
    uint salesDuration; // time interval to sell the instance
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
                  uint _valueXYZ, uint _roundDuration, bytes32 _initialHash,
                  bytes32 _claimerFinalHash, uint _finalTime,
                  uint32 _partitionInstance);
  event DoubleDown(uint32 _index, uint _value);
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
                       bytes32 _initialHash, bytes32 _claimerFinalHash,
                       uint _finalTime)
    public returns (uint32)
  {
    require(tokenContract.transferFrom(msg.sender, address(this), _valueXYZ));
    require(_finalTime > 0);
    instance[currentIndex].challenger = _challenger;
    instance[currentIndex].claimer = _claimer;
    instance[currentIndex].valueXYZ = _valueXYZ;
    instance[currentIndex].challengerPriceXYZ = _valueXYZ;
    instance[currentIndex].claimerPriceXYZ = _valueXYZ;
    instance[currentIndex].salesDuration = _salesDuration;
    instance[currentIndex].roundDuration = _roundDuration;
    instance[currentIndex].initialHash = _initialHash;
    instance[currentIndex].claimerFinalHash = _claimerFinalHash;
    instance[currentIndex].finalTime = _finalTime;
    instance[currentIndex].timeOfLastMove = now;
    instance[currentIndex].currentState = state.WaitSale;
    emit VGCreated(currentIndex, _challenger, _claimer, _valueXYZ,
                   _roundDuration, _initialHash, _claimerFinalHash, _finalTime,
                   instance[currentIndex].partitionInstance);
    currentIndex++;
    return(currentIndex - 1);
  }

  /// @notice During sale phase, anyone can increase the value of an instance
  /// this can be used to signal to buyers that the player is convinced of the
  /// victory and incentivise them to execute the verification off-chain.
  /// Be careful to increase the price before if needed.
  function doubleDown(uint32 _index, uint _value) public {
    require(instance[_index].currentState == state.WaitSale);
    require(tokenContract.transferFrom(msg.sender, address(this), _value));
    emit DoubleDown(_index, _value);
  }

  function setChallengerPrice(uint32 _index, uint _newPrice) public {
    require(instance[_index].currentState == state.WaitSale);
    require(msg.sender == instance[_index].challenger);
    instance[_index].challengerPriceXYZ = _newPrice;
  }

  function setClaimerPrice(uint32 _index, uint _newPrice) public {
    require(instance[_index].currentState == state.WaitSale);
    require(msg.sender == instance[_index].claimer);
    instance[_index].claimerPriceXYZ = _newPrice;
  }

  /// @notice During sale phase, anyone can buy this instance from challenger
  function buyInstanceFromChallenger(uint32 _index) public {
    require(instance[_index].currentState == state.WaitSale);
    require(tokenContract.transferFrom(msg.sender, address(this),
                                       instance[_index].challengerPriceXYZ));
    require(tokenContract.transfer(instance[_index].challenger,
                                   instance[_index].challengerPriceXYZ));
    instance[_index].challenger = msg.sender;
    instance[_index].challengerPriceXYZ = instance[_index].valueXYZ;
  }

  /// @notice During sale phase, anyone can buy this instance from claimer
  function buyInstanceFromClaimer(uint32 _index) public {
    require(instance[_index].currentState == state.WaitSale);
    require(tokenContract.transferFrom(msg.sender, address(this),
                                       instance[_index].claimerPriceXYZ));
    require(tokenContract.transfer(instance[_index].claimer,
                                   instance[_index].claimerPriceXYZ));
    instance[_index].claimer = msg.sender;
    instance[_index].claimerPriceXYZ = instance[_index].valueXYZ;
  }

  /// @notice After five times the round duration, the sale phase can be
  /// finished by anyone.
  function finishSalePhase(uint32 _index) public {
    require(instance[_index].currentState == state.WaitSale);
    require(now > instance[_index].timeOfLastMove
            + instance[_index].salesDuration);
    instance[_index].timeOfLastMove = now;
    instance[_index].partitionInstance =
      partition.instantiate(instance[_index].challenger,
                            instance[_index].claimer,
                            instance[_index].initialHash,
                            instance[_index].claimerFinalHash,
                            instance[_index].finalTime,
                            10,
                            instance[_index].roundDuration);
    instance[_index].currentState = state.WaitPartition;
    emit StartChallenge(_index, instance[_index].partitionInstance);
  }

  /// @notice In case one of the parties wins the partition challenge by
  /// timeout, then he or she can call this function to claim victory in
  /// the hireCPU contract as well.
  function winByPartitionTimeout(uint32 _index) public {
    require(instance[_index].currentState == state.WaitPartition);
    uint32 partitionIndex = instance[_index].partitionInstance;
    if (partition.currentState(partitionIndex)
        == PartitionInterface.state.ChallengerWon)
      { challengerWins(_index); return; }
    if (partition.currentState(partitionIndex)
        == PartitionInterface.state.ClaimerWon)
      { claimerWins(_index); return; }
    require(false);
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
    emit PartitionDivergenceFound(_index, instance[_index].mmInstance);
  }

  /// @notice After having filled the memory manager with the necessary data,
  /// the provider calls this function to instantiate the machine and perform
  /// one step on it. The machine will write to memory now. Later, the
  /// provider will be expected to update the memory hash accordingly.
  function settleVerificationGame(uint32 _index) public {
    require(msg.sender == instance[_index].challenger);
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    uint32 mmIndex = instance[_index].mmInstance;
    require(mm.currentState(mmIndex) == MMInterface.state.WaitingReplay);
    subleq.step(address(mm), mmIndex);
    require(mm.currentState(mmIndex) == MMInterface.state.FinishedReplay);
    //require(mm.newHash(mmIndex) != instance[_index].hashAfterDivergence);
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
      instance[_index].currentState = state.FinishedChallengerWon;
      emit VGFinished(instance[_index].currentState);
  }

  function claimerWins(uint32 _index) private
  {
      tokenContract.transfer(instance[_index].claimer,
                             instance[_index].valueXYZ);
      instance[_index].currentState = state.FinishedClaimerWon;
      emit VGFinished(instance[_index].currentState);
  }

  function currentState(uint32 _index) public view
    returns (VGInstantiator.state)
  {
    return instance[_index].currentState;
  }

}

// @title Verification game instantiator
pragma solidity ^0.4.23;

import "./Decorated.sol";
import "./Instantiator.sol";
import "./VGInterface.sol";
import "./lib/bokkypoobah/Token.sol";

contract ShufflerInstantiator is Decorated, Instantiator
{
  using SafeMath for uint;

  Token private tokenContract; // address of Themis ERC20 contract
  VGInterface private vg;

  enum state { WaitExplanation, WaitChallengedStage, WaitingVG,
               FinishedClaimerWon, FinishedChallengerWon }

  enum stageTypes { Machine, MemoryWrite }

  struct stageDescription
  {
    uint16 rootBefore;
    uint16 rootAfter;
    uint16[4] chuncksBefore;
    uint16[4] chuncksAfter;
    stageType type;
    // for stages of Machine type
    address machine; // the machine which will run the challenge
    uint finalTime; // the time for which the machine should run
    // for stages of MemoryWrite type
    uint64 positionWritten;
    bytes8 valueWritten;
  }

  struct stageExplanation
  {
    bytes32 rootBefore;
    bytes32 rootAfter;
    bytes32[4] chuncksBefore;
    bytes32[4] chuncksAfter;
  }

  // !!!!!!!!! GARBAGE COLLECT THIS !!!!!!!!!
  struct ShuffleCtx
  {
    address challenger; // the two parties involved in each instance
    address claimer;
    uint valueXYZ; // the value given to the winner in XYZ
    uint roundDuration; // time interval to interact with this contract
    uint timeOfLastMove; // last time someone made a move with deadline
    stageDescription[] description;
    stageExplanation[] explanation;
    uint32 vgInstance;
    state currentState;
  }

  mapping(uint32 => ShuffleCtx) private instance;

  // These are the possible states and transitions of the contract.
  //
  //

  event ShufflerCreated(uint32 _index, address _challenger, address _claimer,
                        uint _valueXYZ, uint _roundDuration,
                        uint32 _mmInstance);
  event ShufflerFinished(state _finalState);

  constructor(address _tokenContractAddress,
              address _mmInstantiatorAddress,
              address _vgInstantiatorAddress) public {
    tokenContract = Token(_tokenContractAddress);
    vg = VGInterface(_vgInstantiatorAddress);
  }

  function instantiate(address _challenger, address _claimer, uint _valueXYZ,
                       uint _roundDuration,
                       uint16[] _hashes,
                       uint8[] _type,
                       address[] _machine,
                       uint[] _finalTime,
                       uint64[] _positionWritten,
                       bytes8[] _valueWritten)
    public returns (uint32)
  {
    require(tokenContract.transferFrom(msg.sender, address(this), _valueXYZ));
    uint descriptionSize = _type.length;
    require(_hashes.length == descriptionSize.mul(10));
    require(_machine.length == descriptionSize);
    require(_finalTime.length == descriptionSize);
    require(_positionWritten.length == descriptionSize);
    require(_valueWritten.length == descriptionSize);
    instance[currentIndex].challenger = _challenger;
    instance[currentIndex].claimer = _claimer;
    instance[currentIndex].valueXYZ = _valueXYZ;
    instance[currentIndex].roundDuration = _roundDuration;
    instance[currentIndex].timeOfLastMove = now;
    instance[currentIndex].currentState = state.WaitExplanation;
    emit ShufflerCreated(currentIndex, _challenger, _claimer, _valueXYZ,
                         _roundDuration);
    currentIndex++;
    return(currentIndex - 1);
  }

  /// @notice After having filled the memory manager with the necessary data,
  /// the claimer calls this function to verify the change
  function settleMemoryGame(uint32 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].claimer)
  {
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    uint32 mmIndex = instance[_index].mmInstance;
    require(mm.stateIsWaitingReplay(mmIndex));
    mm.write(instance[_index].mmInstance,
             instance[_index].positionWritten,
             instance[_index].valueWritten);
    require(mm.stateIsFinishedReplay(mmIndex));
    require(mm.newHash(mmIndex) == instance[_index].claimerFinalHash);
    claimerWins(_index);
  }

  /// @notice Claimer can claim victory if challenger has lost the deadline
  /// for some of the steps in the protocol.
  function claimVictoryByDeadline(uint32 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].challenger)
    onlyAfter(instance[_index].timeOfLastMove + instance[_index].roundDuration)
  {
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    challengerWins(_index);
  }

  // !!!!!!!!! SEND THESE TWO METHODS TO A GAME BASE CONTRACT !!!!!!!!!
  function challengerWins(uint32 _index) private
    onlyInstantiated(_index)
  {
      tokenContract.transfer(instance[_index].challenger,
                             instance[_index].valueXYZ);
      clearInstance(_index);
      instance[_index].currentState = state.FinishedChallengerWon;
      emit MGFinished(instance[_index].currentState);
  }

  function claimerWins(uint32 _index) private
    onlyInstantiated(_index)
  {
      tokenContract.transfer(instance[_index].claimer,
                             instance[_index].valueXYZ);
      clearInstance(_index);
      instance[_index].currentState = state.FinishedClaimerWon;
      emit MGFinished(instance[_index].currentState);
  }

  function clearInstance(uint32 _index) internal
    onlyInstantiated(_index)
  {
    delete instance[_index].challenger;
    delete instance[_index].claimer;
    delete instance[_index].valueXYZ;
    delete instance[_index].roundDuration;
    delete instance[_index].initialHash;
    delete instance[_index].claimerFinalHash;
    delete instance[_index].positionWritten;
    delete instance[_index].valueWritten;
    delete instance[_index].timeOfLastMove;
    // !!!!!!!!! should call delete in mmInstance !!!!!!!!!
    delete instance[_index].mmInstance;
  }

  // state getters
  function stateIsWaitMemoryProveValues(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitMemoryProveValues; }

  // !!!!!!!!! SEND THESE TWO METHODS TO A GAME BASE CONTRACT !!!!!!!!!
  function stateIsFinishedClaimerWon(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedClaimerWon; }

  function stateIsFinishedChallengerWon(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedClaimerWon; }

  function getStateWaitExplanation() public pure returns (uint8)
  { return uint8(state.WaitExplanation); }

  function getStateWaitChallengedStage() public pure returns (uint8)
  { return uint8(state.WaitChallengedStage); }

  function getStateWaitingVG() public pure returns (uint8)
  { return uint8(state.WaitingVG); }

  function getStateFinishedClaimerWon() public pure returns (uint8)
  { return uint8(state.FinishedClaimerWon); }

  function getStateFinishedChallengerWon() public pure returns (uint8)
  { return uint8(state.FinishedChallengerWon); }
}

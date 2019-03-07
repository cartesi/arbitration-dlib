// @title Verification game instantiator
pragma solidity ^0.4.23;

import "./Decorated.sol";
import "./Instantiator.sol";
import "./MMInterface.sol";
import "./lib/bokkypoobah/Token.sol";

contract MemoryGameInstantiator is Decorated, Instantiator
{
  using SafeMath for uint;

  Token private tokenContract; // address of Themis ERC20 contract
  MMInterface private mm;

  enum state { WaitMemoryProveValues, FinishedClaimerWon,
               FinishedChallengerWon }

  // !!!!!!!!! GARBAGE COLLECT THIS !!!!!!!!!
  struct MGCtx
  {
    address challenger; // the two parties involved in each instance
    address claimer;
    uint valueXYZ; // the value given to the winner in XYZ
    uint roundDuration; // time interval to interact with this contract
    bytes32 initialHash; // hash of machine memory that both aggree uppon
    bytes32 claimerFinalHash; // hash claimer commited for machine after running
    uint64 positionWritten;
    uint64 valueWritten;
    uint timeOfLastMove; // last time someone made a move with deadline
    uint256 mmInstance; // the instance of the memory that was given to this game
    state currentState;
  }

  mapping(uint256 => MGCtx) private instance;

  // These are the possible states and transitions of the contract.
  //
  //               +---+
  //               |   |
  //               +---+
  //                 |
  //                 | instantiate
  //                 v
  //               +-----------------------+
  //     +---------| WaitMemoryProveValues |----------------+
  //     |         +-----------------------+                |
  //     |                                                  |
  //     | claimVictoryByDeadline          settleMemoryGame |
  //     v                                                  v
  // +--------------------+               +-----------------------+
  // | FinishedClaimerWon |               | FinishedChallengerWon |
  // +--------------------+               +-----------------------+
  //

  event MGCreated(uint256 _index, address _challenger, address _claimer,
                  uint _valueXYZ, uint _roundDuration, bytes32 _initialHash,
                  bytes32 _claimerFinalHash, uint256 _mmInstance);
  event MemoryWriten(uint256 _index);
  event MGFinished(state _finalState);

  constructor(address _tokenContractAddress,
              address _mmInstantiatorAddress) public {
    tokenContract = Token(_tokenContractAddress);
    mm = MMInterface(_mmInstantiatorAddress);
  }

  function instantiate(address _challenger, address _claimer, uint _valueXYZ,
                       uint _roundDuration, bytes32 _initialHash,
                       bytes32 _claimerFinalHash, uint64 _positionWritten,
                       uint64 _valueWritten)
    public returns (uint256)
  {
    require(tokenContract.transferFrom(msg.sender, address(this), _valueXYZ));
    require((_positionWritten & 7) == 0);
    instance[currentIndex].challenger = _challenger;
    instance[currentIndex].claimer = _claimer;
    instance[currentIndex].valueXYZ = _valueXYZ;
    instance[currentIndex].roundDuration = _roundDuration;
    instance[currentIndex].initialHash = _initialHash;
    instance[currentIndex].claimerFinalHash = _claimerFinalHash;
    instance[currentIndex].positionWritten = _positionWritten;
    instance[currentIndex].valueWritten = _valueWritten;
    instance[currentIndex].timeOfLastMove = now;
    instance[currentIndex].currentState = state.WaitMemoryProveValues;
    instance[currentIndex].mmInstance =
      mm.instantiate(_challenger, address(this), _initialHash);
    emit MGCreated(currentIndex, _challenger, _claimer, _valueXYZ,
                   _roundDuration, _initialHash,
                   _claimerFinalHash, instance[currentIndex].mmInstance);

    active[currentIndex] = true;
    return(currentIndex++);
  }

  /// @notice After having filled the memory manager with the necessary data,
  /// the claimer calls this function to verify the change
  function settleMemoryGame(uint256 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].claimer)
    increasesNonce(_index)
  {
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    uint256 mmIndex = instance[_index].mmInstance;
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
  function claimVictoryByDeadline(uint256 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].challenger)
    onlyAfter(instance[_index].timeOfLastMove + instance[_index].roundDuration)
  {
    require(instance[_index].currentState == state.WaitMemoryProveValues);
    challengerWins(_index);
  }

  // !!!!!!!!! SEND THESE TWO METHODS TO A GAME BASE CONTRACT !!!!!!!!!
  function challengerWins(uint256 _index) private
    onlyInstantiated(_index)
  {
      tokenContract.transfer(instance[_index].challenger,
                             instance[_index].valueXYZ);
      clearInstance(_index);
      instance[_index].currentState = state.FinishedChallengerWon;
      emit MGFinished(instance[_index].currentState);
  }

  function claimerWins(uint256 _index) private
    onlyInstantiated(_index)
  {
      tokenContract.transfer(instance[_index].claimer,
                             instance[_index].valueXYZ);
      clearInstance(_index);
      instance[_index].currentState = state.FinishedClaimerWon;
      emit MGFinished(instance[_index].currentState);
  }

  function clearInstance(uint256 _index) internal
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
    deactivate(_index);
  }

  // state getters
  function isConcerned(uint256 _index, address _user) public view returns(bool)
  {
    return ((instance[_index].challenger == _user)
            || (instance[_index].claimer == _user));
  }

  function stateIsWaitMemoryProveValues(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitMemoryProveValues; }

  // !!!!!!!!! SEND THESE TWO METHODS TO A GAME BASE CONTRACT !!!!!!!!!
  function stateIsFinishedClaimerWon(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedClaimerWon; }

  function stateIsFinishedChallengerWon(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedClaimerWon; }
}

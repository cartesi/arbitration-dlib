/// @title An instantiator of memory managers
pragma solidity 0.4.24;

import "./Decorated.sol";
import "./MMInterface.sol";
import "./Merkle.sol";

contract MMInstantiator is MMInterface, Decorated {
  // the privider will fill the memory for the client to read and write
  // memory starts with hash and all values that are inserted are first verified
  // then client can read inserted values and write some more
  // finally the provider has to update the hash to account for writes

  struct ReadWrite {
    bool wasRead;
    uint64 position;
    bytes8 value;
  }

  // IMPLEMENT GARBAGE COLLECTOR AFTER AN INSTACE IS FINISHED!
  struct MMCtx {
    address provider;
    address client;
    bytes32 initialHash;
    bytes32 newHash; // hash after some write operations have been proved
    ReadWrite[] history;
    uint historyPointer;
    state currentState;
  }

  mapping(uint32 => MMCtx) private instance;

  // These are the possible states and transitions of the contract.
  //
  // +---+
  // |   |
  // +---+
  //   |
  //   | instantiate
  //   v
  // +---------------+    | proveRead
  // | WaitingProofs |----| proveWrite
  // +---------------+
  //   |
  //   | finishProofPhase
  //   v
  // +----------------+    |read
  // | FinishedReplay |----|write
  // +----------------+
  //   |
  //   | finishReplayPhase
  //   v
  // +---------------+
  // | WaitingReplay |
  // +---------------+
  //

  event MemoryCreated(uint32 _index, bytes32 _initialHash);
  event ValueProved(uint32 _index, bool _wasRead, uint64 _position,
                    bytes8 _value);
  event ValueRead(uint32 _index, uint64 _position, bytes8 _value);
  event ValueWritten(uint32 _index, uint64 _position, bytes8 _value);
  event FinishedProofs(uint32 _index);
  event FinishedReplay(uint32 _index);

  function instantiate(address _provider, address _client,
                       bytes32 _initialHash) public returns (uint32)
  {
    require(_provider != _client);
    instance[currentIndex].provider = _provider;
    instance[currentIndex].client = _client;
    instance[currentIndex].initialHash = _initialHash;
    instance[currentIndex].newHash = _initialHash;
    instance[currentIndex].historyPointer = 0;
    instance[currentIndex].currentState = state.WaitingProofs;
    emit MemoryCreated(currentIndex, _initialHash);
    currentIndex++;
    return(currentIndex - 1);
  }

  /// @notice Proves that a certain value in current memory is correct
  // @param _position The address of the value to be confirmed
  // @param _value The value in that address to be confirmed
  // @param proof The proof that this value is correct
  function proveRead(uint32 _index, uint64 _position, bytes8 _value,
                     bytes32[] proof) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].provider)
  {
    require(instance[_index].currentState == state.WaitingProofs);
    require(Merkle.getRoot(_position, _value, proof)
            == instance[_index].newHash);
    instance[_index].history.push(ReadWrite(true, _position, _value));
    emit ValueProved(_index, true, _position, _value);
  }

  /// @notice Register a write operation and update newHash
  /// @param _position to be written
  /// @param _oldValue before write
  /// @param _newValue to be written
  /// @param proof The proof that the old value was correct
  function proveWrite(uint32 _index, uint64 _position,
                      bytes8 _oldValue, bytes8 _newValue,
                      bytes32[] proof) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].provider)
  {
    require(instance[_index].currentState == state.WaitingProofs);
    // check proof of old value
    require(Merkle.getRoot(_position, _oldValue, proof)
            == instance[_index].newHash);
    // update root
    instance[_index].newHash =
      Merkle.getRoot(_position, _newValue, proof);
    instance[_index].history
      .push(ReadWrite(false, _position, _newValue));
    emit ValueProved(_index, false, _position, _newValue);
  }

  /// @notice Stop memory insertion and start read and write phase
  function finishProofPhase(uint32 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].provider)
  {
    require(instance[_index].currentState == state.WaitingProofs);
    instance[_index].currentState = state.WaitingReplay;
    emit FinishedProofs(_index);
  }

  /// @notice Replays a read in memory that has been proved to be correct
  /// according to initial hash
  /// @param _position of the desired memory
  function read(uint32 _index, uint64 _position) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].client)
    returns (bytes8)
  {
    require(instance[_index].currentState == state.WaitingReplay);
    require((_position & 7) == 0);
    uint pointer = instance[_index].historyPointer;
    require(instance[_index].history[pointer].wasRead);
    require(instance[_index].history[pointer].position == _position);
    bytes8 value = instance[_index].history[pointer].value;
    delete(instance[_index].history[pointer]);
    instance[_index].historyPointer++;
    emit ValueRead(_index, _position, value);
    return value;
  }

  /// @notice Replays a write in memory that was proved correct
  /// @param _position of the write
  /// @param _value to be written
  function write(uint32 _index, uint64 _position, bytes8 _value) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].client)
  {
    require(instance[_index].currentState == state.WaitingReplay);
    require((_position & 7) == 0);
    uint pointer = instance[_index].historyPointer;
    require(!instance[_index].history[pointer].wasRead);
    require(instance[_index].history[pointer].position == _position);
    require(instance[_index].history[pointer].value == _value);
    delete(instance[_index].history[pointer]);
    instance[_index].historyPointer++;
    emit ValueWritten(_index, _position, _value);
  }

  /// @notice Stop write (or read) phase
  function finishReplayPhase(uint32 _index) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].client)
  {
    require(instance[_index].currentState == state.WaitingReplay);
    require(instance[_index].historyPointer == instance[_index].history.length);
    delete(instance[_index].history);
    delete(instance[_index].historyPointer);
    instance[_index].currentState = state.FinishedReplay;
    emit FinishedReplay(_index);
  }

  // getter methods
  function provider(uint32 _index) public view
    onlyInstantiated(_index)
    returns (address)
  { return instance[_index].provider; }

  function client(uint32 _index) public view
    onlyInstantiated(_index)
    returns (address)
  { return instance[_index].client; }

  function initialHash(uint32 _index) public view
    onlyInstantiated(_index)
    returns (bytes32)
  { return instance[_index].initialHash; }

  function newHash(uint32 _index) public view
    onlyInstantiated(_index)
    returns (bytes32)
  { return instance[_index].newHash; }

  // state getters

  function stateIsWaitingProofs(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitingProofs; }

  function stateIsWaitingReplay(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitingReplay; }

  function stateIsFinishedReplay(uint32 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.FinishedReplay; }
}

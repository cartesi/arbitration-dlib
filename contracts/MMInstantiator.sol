/// @title An instantiator of memory managers
pragma solidity ^0.4.18;

import "./MMInterface.sol";

contract MMInstantiator is MMInterface {
  uint32 private currentIndex = 0;

  // the privider will fill the memory for the client to read and write
  // memory starts with hash and all values that are inserted are first verified
  // then client can read inserted values and write some more
  // finally the provider has to update the hash to account for writes

  // IMPLEMENT GARBAGE COLLECTOR AFTER AN INSTACE IS FINISHED!
  struct MMCtx {
    address provider;
    address client;
    bytes32 initialHash;
    bytes32 newHash; // hash after some write operations have been proved
    mapping(uint64 => bool) addressWasSubmitted; // mark address submitted
    mapping(uint64 => bytes8) valueSubmitted; // value submitted to address
    mapping(uint64 => bool) addressWasWritten; // marks address as written
    mapping(uint64 => bytes8) valueWritten; // value written to address
    uint64[] writtenAddress;
    state currentState;
  }

  mapping(uint32 => MMCtx) private instance;

  event MemoryCreated(uint32 _index, bytes32 _initialHash);
  event ValueSubmitted(uint32 _index, uint64 _addressSubmitted,
                       bytes8 _valueSubmitted);
  event FinishedSubmittions(uint32 _index);
  event FinishedReading(uint32 _index);
  event ValueWritten(uint32 _index, uint64 _addressSubmitted,
                     bytes8 _valueSubmitted);
  event FinishedWriting(uint32 _index);
  event HashUpdated(uint32 _index, uint64 _addressSubmitted,
                    bytes8 _valueSubmitted,
                    bytes32 _newHash);
  event FinishedUpdating(uint32 _index);

  function instantiate(address _provider, address _client,
                       bytes32 _initialHash) public returns (uint32)
  {
    require(_provider != _client);
    instance[currentIndex].provider = _provider;
    instance[currentIndex].client = _client;
    instance[currentIndex].initialHash = _initialHash;
    instance[currentIndex].newHash = _initialHash;
    instance[currentIndex].currentState = state.WaitingValues;
    emit MemoryCreated(currentIndex, _initialHash);
    currentIndex++;
    return(currentIndex - 1);
  }

  /// @notice Proves that a certain value in initial memory is correct
  /// @param _address The address of the value to be confirmed
  /// @param _value The value in that address to be confirmed
  /// @param proof The proof that this value is correct
  function proveValue(uint32 _index, uint64 _address, bytes8 _value,
                      bytes32[] proof) public
  {
    require(msg.sender == instance[_index].provider);
    require(instance[_index].currentState == state.WaitingValues);
    require((_address & 7) == 0);
    require(proof.length == 61);
    bytes32 runningHash = keccak256(_value);
    // iterate the hash with the uncle subtree provided in proof
    uint64 eight = 8;
    for (uint i = 0; i < 61; i++) {
      if ((_address & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    require (runningHash == instance[_index].initialHash);
    instance[_index].addressWasSubmitted[_address] = true;
    instance[_index].valueSubmitted[_address] = _value;
    emit ValueSubmitted(_index, _address, _value);
  }

  /// @notice Stop memory insertion and start read and write phase
  function finishSubmissionPhase(uint32 _index) public {
    require(msg.sender == instance[_index].provider);
    require(instance[_index].currentState == state.WaitingValues);
    instance[_index].currentState = state.Reading;
    emit FinishedSubmittions(_index);
  }

  /// @notice reads a slot in memory that has been proved to be correct
  /// according to initial hash
  /// @param _address of the desired memory
  function read(uint32 _index, uint64 _address)
    public view returns (bytes8)
  {
    require(msg.sender == instance[_index].client);
    require(instance[_index].currentState == state.Reading);
    require((_address & 7) == 0);
    require(instance[_index].addressWasSubmitted[_address]);
    return instance[_index].valueSubmitted[_address];
  }

  /// @notice writes on a slot of memory during read or write phase
  /// if in reading phase, change to writing
  /// @param _address of the write
  /// @param _value to be written
  function write(uint32 _index, uint64 _address, bytes8 _value)
    public
  {
    require(msg.sender == instance[_index].client);
    require((instance[_index].currentState == state.Reading)
            || (instance[_index].currentState == state.Writing));
    require((_address & 7) == 0);
    require(instance[_index].addressWasSubmitted[_address]);
    require(!instance[_index].addressWasWritten[_address]);
    if (instance[_index].currentState == state.Reading) {
      instance[_index].currentState = state.Writing;
      emit FinishedReading(_index);
    }
    instance[_index].addressWasWritten[_address] = true;
    instance[_index].valueWritten[_address] = _value;
    instance[_index].writtenAddress.push(_address);
    emit ValueWritten(_index, _address, _value);
  }

  /// @notice Stop write (or read) phase
  function finishWritePhase(uint32 _index) public {
    require(msg.sender == instance[_index].client);
    require((instance[_index].currentState == state.Writing)
            || (instance[_index].currentState == state.Reading));
    instance[_index].currentState = state.UpdatingHashes;
    emit FinishedWriting(_index);
  }

  /// @notice Update hash corresponding to write
  /// @param proof The proof that the new value is correct
  function updateHash(uint32 _index, bytes32[] proof) public {
    require(msg.sender == instance[_index].provider);
    require(instance[_index].currentState == state.UpdatingHashes);
    require(instance[_index].writtenAddress.length > 0);
    uint64 _address = instance[_index].writtenAddress
      [instance[_index].writtenAddress.length - 1];
    require((_address & 7) == 0);
    require(instance[_index].addressWasSubmitted[_address]);
    require(instance[_index].addressWasWritten[_address]);
    require(proof.length == 61);
    bytes8 oldValue = instance[_index].valueSubmitted[_address];
    bytes8 newValue = instance[_index].valueWritten[_address];
    // verifying the proof of the old value
    bytes32 runningHash = keccak256(oldValue);
    uint64 eight = 8;
    for (uint i = 0; i < 61; i++) {
      if ((_address & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    require (runningHash == instance[_index].newHash);
    // find out new hash after write
    runningHash = keccak256(newValue);
    for (i = 0; i < 61; i++) {
      if ((_address & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    instance[_index].newHash = runningHash;
    instance[_index].writtenAddress.length--;
    emit HashUpdated(_index, _address, newValue, instance[_index].newHash);
  }

  /// @notice Finishes updating the hash
  function finishUpdateHashPhase(uint32 _index) public {
    require(msg.sender == instance[_index].provider);
    require(instance[_index].currentState == state.UpdatingHashes);
    require(instance[_index].writtenAddress.length == 0);
    instance[_index].currentState = state.FinishedUpdating;
    emit FinishedUpdating(_index);
  }

  // getter methods
  function provider(uint32 _index) public view returns (address) {
    return instance[_index].provider;
  }

  function client(uint32 _index) public view returns (address) {
    return instance[_index].client;
  }

  function initialHash(uint32 _index) public view returns (bytes32) {
    return instance[_index].initialHash;
  }

  function newHash(uint32 _index) public view returns (bytes32) {
    return instance[_index].newHash;
  }

  function currentState(uint32 _index) public view
    returns (MMInstantiator.state)
  {
    return instance[_index].currentState;
  }

  function addressWasSubmitted(uint32 _index, uint64 key) public view
    returns (bool)
  {
    return instance[_index].addressWasSubmitted[key];
  }

  function valueSubmitted(uint32 _index, uint64 key) public view
    returns (bytes8)
  {
    return instance[_index].valueSubmitted[key];
  }

  function writtenAddress(uint32 _index, uint64 position) public view
    returns (uint64)
  {
    return instance[_index].writtenAddress[position];
  }

  function addressWasWritten(uint32 _index, uint64 addr) public view
    returns (bool)
  {
    return instance[_index].addressWasWritten[addr];
  }

  function valueWritten(uint32 _index, uint64 addr) public view
    returns (bytes8)
  {
    return instance[_index].valueWritten[addr];
  }

  function getWrittenAddressLength(uint32 _index) public view returns (uint) {
    return instance[_index].writtenAddress.length;
  }
}


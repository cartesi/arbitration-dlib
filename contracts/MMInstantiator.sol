/// @title An instantiator of memory managers
pragma solidity ^0.4.18;

contract MMInstantiator {
  uint32 currentIndex = 0;

  enum state { WaitingValues, Reading, Writing, UpdatingHashes,
               FinishedUpdating }

  // the privider will fill the memory for the client to read and write
  // memory starts with hash and all values that are inserted are first verified
  // then client can read inserted values and write some more
  // finally the provider has to update the hash to account for writes

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

  mapping(uint32 => MMCtx) private instances;

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
                       bytes32 _initialHash) public
  {
    require(_provider != _client);
    instances[currentIndex].provider = _provider;
    instances[currentIndex].client = _client;
    instances[currentIndex].initialHash = _initialHash;
    instances[currentIndex].newHash = _initialHash;
    instances[currentIndex].currentState = state.WaitingValues;
    emit MemoryCreated(currentIndex, _initialHash);
    currentIndex++;
  }

  /// @notice Proves that a certain value in initial memory is correct
  /// @param _address The address of the value to be confirmed
  /// @param _value The value in that address to be confirmed
  /// @param proof The proof that this value is correct
  function proveValue(uint32 _index, uint64 _address, bytes8 _value,
                      bytes32[] proof) public
  {
    require(msg.sender == instances[_index].provider);
    require(instances[_index].currentState == state.WaitingValues);
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
    require (runningHash == instances[_index].initialHash);
    instances[_index].addressWasSubmitted[_address] = true;
    instances[_index].valueSubmitted[_address] = _value;
    emit ValueSubmitted(_index, _address, _value);
  }

  /// @notice Stop memory insertion and start read and write phase
  function finishSubmissionPhase(uint32 _index) public {
    require(msg.sender == instances[_index].provider);
    require(instances[_index].currentState == state.WaitingValues);
    instances[_index].currentState = state.Reading;
    emit FinishedSubmittions(_index);
  }

  /// @notice reads a slot in memory that has been proved to be correct
  /// according to initial hash
  /// @param _address of the desired memory
  function read(uint32 _index, uint64 _address)
    public view returns (bytes8)
  {
    require(msg.sender == instances[_index].client);
    require(instances[_index].currentState == state.Reading);
    require((_address & 7) == 0);
    require(instances[_index].addressWasSubmitted[_address]);
    return instances[_index].valueSubmitted[_address];
  }

  /// @notice writes on a slot of memory during read or write phase
  /// if in reading phase, change to writing
  /// @param _address of the write
  /// @param _value to be written
  function write(uint32 _index, uint64 _address, bytes8 _value)
    public
  {
    require(msg.sender == instances[_index].client);
    require((instances[_index].currentState == state.Reading)
            || (instances[_index].currentState == state.Writing));
    require((_address & 7) == 0);
    require(instances[_index].addressWasSubmitted[_address]);
    require(!instances[_index].addressWasWritten[_address]);
    if (instances[_index].currentState == state.Reading) {
      instances[_index].currentState = state.Writing;
      emit FinishedReading(_index);
    }
    instances[_index].addressWasWritten[_address] = true;
    instances[_index].valueWritten[_address] = _value;
    instances[_index].writtenAddress.push(_address);
    emit ValueWritten(_index, _address, _value);
  }

  /// @notice Stop write (or read) phase
  function finishWritePhase(uint32 _index) public {
    require(msg.sender == instances[_index].client);
    require((instances[_index].currentState == state.Writing)
            || (instances[_index].currentState == state.Reading));
    instances[_index].currentState = state.UpdatingHashes;
    emit FinishedWriting(_index);
  }

  /// @notice Update hash corresponding to write
  /// @param proof The proof that the new value is correct
  function updateHash(uint32 _index, bytes32[] proof) public {
    require(msg.sender == instances[_index].provider);
    require(instances[_index].currentState == state.UpdatingHashes);
    require(instances[_index].writtenAddress.length > 0);
    uint64 _address = instances[_index].writtenAddress
      [instances[_index].writtenAddress.length - 1];
    require((_address & 7) == 0);
    require(instances[_index].addressWasSubmitted[_address]);
    require(instances[_index].addressWasWritten[_address]);
    require(proof.length == 61);
    bytes8 oldValue = instances[_index].valueSubmitted[_address];
    bytes8 newValue = instances[_index].valueWritten[_address];
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
    require (runningHash == instances[_index].newHash);
    // find out new hash after write
    runningHash = keccak256(newValue);
    for (i = 0; i < 61; i++) {
      if ((_address & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    instances[_index].newHash = runningHash;
    instances[_index].writtenAddress.length--;
    emit HashUpdated(_index, _address, newValue, instances[_index].newHash);
  }

  /// @notice Finishes updating the hash
  function finishUpdateHashPhase(uint32 _index) public {
    require(msg.sender == instances[_index].provider);
    require(instances[_index].currentState == state.UpdatingHashes);
    require(instances[_index].writtenAddress.length == 0);
    instances[_index].currentState = state.FinishedUpdating;
    emit FinishedUpdating(_index);
  }

  // getter methods
  function provider(uint32 _index) public view returns (address) {
    return instances[_index].provider;
  }

  function client(uint32 _index) public view returns (address) {
    return instances[_index].client;
  }

  function initialHash(uint32 _index) public view returns (bytes32) {
    return instances[_index].initialHash;
  }

  function newHash(uint32 _index) public view returns (bytes32) {
    return instances[_index].newHash;
  }

  function currentState(uint32 _index) public view
    returns (MMInstantiator.state)
  {
    return instances[_index].currentState;
  }

  function addressWasSubmitted(uint32 _index, uint64 key) public view
    returns (bool)
  {
    return instances[_index].addressWasSubmitted[key];
  }

  function valueSubmitted(uint32 _index, uint64 key) public view
    returns (bytes8)
  {
    return instances[_index].valueSubmitted[key];
  }

  function writtenAddress(uint32 _index, uint64 position) public view
    returns (uint64)
  {
    return instances[_index].writtenAddress[position];
  }

  function addressWasWritten(uint32 _index, uint64 addr) public view
    returns (bool)
  {
    return instances[_index].addressWasWritten[addr];
  }

  function valueWritten(uint32 _index, uint64 addr) public view
    returns (bytes8)
  {
    return instances[_index].valueWritten[addr];
  }

  function getWrittenAddressLength(uint32 _index) public view returns (uint) {
    return instances[_index].writtenAddress.length;
  }
}


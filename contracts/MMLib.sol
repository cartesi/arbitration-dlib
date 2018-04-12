/// @title Memory manager contract
pragma solidity ^0.4.18;

library MMLib {
  // the privider will fill the memory for the client to read and write
  // memory starts with hash and all values that are inserted are first verified
  // then client can read inserted values and write some more
  // finally the provider has to update the hash to account for writes

  enum state { WaitingValues, Reading, Writing, UpdatingHashes, Finished }

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

  event MemoryCreated(bytes32 _initialHash);
  event ValueSubmitted(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedSubmittions();
  event FinishedReading();
  event ValueWritten(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedWriting();
  event HashUpdated(uint64 addressSubmitted, bytes8 valueSubmitted,
                    bytes32 newHash);
  event Finished();

  function init(MMCtx storage self, address _provider, address _client,
                bytes32 _initialHash) public
  {
    require(_provider != _client);
    self.provider = _provider;
    self.client = _client;
    self.initialHash = _initialHash;
    self.newHash = _initialHash;

    self.currentState = state.WaitingValues;
    emit MemoryCreated(self.initialHash);
  }

  /// @notice Change the client of the memory for the possible situations
  /// where the client was not known at time of creation
  /// @param _newClient the address of the new client
  /* function changeClient(address _newClient) public { */
  /*   if (msg.sender == owner) { */
  /*     client = _newClient; */
  /*   } */
  /* } */

  /// @notice Proves that a certain value in initial memory is correct
  /// @param _address The address of the value to be confirmed
  /// @param _value The value in that address to be confirmed
  /// @param proof The proof that this value is correct
  function proveValue(MMCtx storage self, uint64 _address, bytes8 _value,
                      bytes32[] proof) public
  {
    require(msg.sender == self.provider);
    require(self.currentState == state.WaitingValues);
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
    require (runningHash == self.initialHash);
    self.addressWasSubmitted[_address] = true;
    self.valueSubmitted[_address] = _value;

    emit ValueSubmitted(_address, _value);
  }

  /// @notice Stop memory insertion and start read and write phase
  function finishSubmissionPhase(MMCtx storage self) public {
    require(msg.sender == self.provider);
    require(self.currentState == state.WaitingValues);
    self.currentState = state.Reading;
    emit FinishedSubmittions();
  }

  /// @notice reads a slot in memory that has been proved to be correct
  /// according to initial hash
  /// @param _address of the desired memory
  function read(MMCtx storage self, uint64 _address)
    public view returns (bytes8)
  {
    require(self.currentState == state.Reading);
    require((_address & 7) == 0);
    require(self.addressWasSubmitted[_address]);
    return self.valueSubmitted[_address];
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param _address of the write
  /// @param _value to be written
  function write(MMCtx storage self, uint64 _address, bytes8 _value)
    public
  {
    require(msg.sender == self.client);
    require((self.currentState == state.Reading)
            || (self.currentState == state.Writing));
    require((_address & 7) == 0);
    require(self.addressWasSubmitted[_address]);
    require(!self.addressWasWritten[_address]);
    if (self.currentState == state.Reading) {
      self.currentState = state.Writing;
      emit FinishedReading();
    }
    self.addressWasWritten[_address] = true;
    self.valueWritten[_address] = _value;
    self.writtenAddress.push(_address);
    emit ValueWritten(_address, _value);
  }

  /// @notice Stop write phase
  function finishWritePhase(MMCtx storage self) public {
    require(msg.sender == self.client);
    require((self.currentState == state.Writing)
            || (self.currentState == state.Reading));
    self.currentState = state.UpdatingHashes;
    emit FinishedWriting();
  }

  /// @notice Update hash corresponding to write
  /// @param proof The proof that the new value is correct
  function updateHash(MMCtx storage self, bytes32[] proof) public {
    require(msg.sender == self.provider);
    require(self.currentState == state.UpdatingHashes);
    require(self.writtenAddress.length > 0);
    uint64 _address = self.writtenAddress[self.writtenAddress.length - 1];
    require((_address & 7) == 0);
    require(self.addressWasSubmitted[_address]);
    require(self.addressWasWritten[_address]);
    require(proof.length == 61);
    bytes8 oldValue = self.valueSubmitted[_address];
    bytes8 newValue = self.valueWritten[_address];
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
    require (runningHash == self.newHash);
    // find out new hash after write
    runningHash = keccak256(newValue);
    for (i = 0; i < 61; i++) {
      if ((_address & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    self.newHash = runningHash;
    self.writtenAddress.length = self.writtenAddress.length - 1;
    emit HashUpdated(_address, newValue, self.newHash);
  }

  /// @notice Finishes updating the hash
  function finishUpdateHashPhase(MMCtx storage self) public {
    require(msg.sender == self.provider);
    require(self.currentState == state.UpdatingHashes);
    require(self.writtenAddress.length == 0);
    self.currentState = state.Finished;
    emit Finished();
  }
}


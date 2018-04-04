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

  //function getWrittenAddressLength() public constant returns(uint) {
  //  return writtenAddress.length;
  //}

  event MemoryCreated(bytes32 theInitialHash);
  event ValueSubmitted(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedSubmittions();
  event FinishedReading();
  event ValueWritten(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedWriting();
  event HashUpdated(uint64 addressSubmitted, bytes8 valueSubmitted,
                    bytes32 newHash);
  event Finished();

  function init(MMCtx storage self, address theProvider, address theClient,
                bytes32 theInitialHash) public
  {
    require(theProvider != theClient);
    self.provider = theProvider;
    self.client = theClient;
    self.initialHash = theInitialHash;
    self.newHash = theInitialHash;

    self.currentState = state.WaitingValues;
    emit MemoryCreated(theInitialHash);
  }

  /// @notice Change the client of the memory for the possible situations
  /// where the client was not known at time of creation
  /// @param theNewClient the address of the new client
  /* function changeClient(address theNewClient) public { */
  /*   if (msg.sender == owner) { */
  /*     client = theNewClient; */
  /*   } */
  /* } */

  /// @notice Proves that a certain value in initial memory is correct
  /// @param theAddress The address of the value to be confirmed
  /// @param theValue The value in that address to be confirmed
  /// @param proof The proof that this value is correct
  function proveValue(MMCtx storage self, uint64 theAddress, bytes8 theValue,
                      bytes32[] proof) public
  {
    require(msg.sender == self.provider);
    require(self.currentState == state.WaitingValues);
    require((theAddress & 7) == 0);
    require(proof.length == 61);
    bytes32 runningHash = keccak256(theValue);
    // iterate the hash with the uncle subtree provided in proof
    uint64 eight = 8;
    for (uint i = 0; i < 61; i++) {
      if ((theAddress & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    require (runningHash == self.initialHash);
    self.addressWasSubmitted[theAddress] = true;
    self.valueSubmitted[theAddress] = theValue;

    emit ValueSubmitted(theAddress, theValue);
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
  /// @param theAddress of the desired memory
  function read(MMCtx storage self, uint64 theAddress)
    public view returns (bytes8)
  {
    require(self.currentState == state.Reading);
    require((theAddress & 7) == 0);
    require(self.addressWasSubmitted[theAddress]);
    return self.valueSubmitted[theAddress];
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param theAddress of the write
  /// @param theValue to be written
  function write(MMCtx storage self, uint64 theAddress, bytes8 theValue)
    public
  {
    require(msg.sender == self.client);
    require((self.currentState == state.Reading)
            || (self.currentState == state.Writing));
    require((theAddress & 7) == 0);
    require(self.addressWasSubmitted[theAddress]);
    require(!self.addressWasWritten[theAddress]);
    if (self.currentState == state.Reading) {
      self.currentState = state.Writing;
      emit FinishedReading();
    }
    self.addressWasWritten[theAddress] = true;
    self.valueWritten[theAddress] = theValue;
    self.writtenAddress.push(theAddress);
    emit ValueWritten(theAddress, theValue);
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
    uint64 theAddress = self.writtenAddress[self.writtenAddress.length - 1];
    require((theAddress & 7) == 0);
    require(self.addressWasSubmitted[theAddress]);
    require(self.addressWasWritten[theAddress]);
    require(proof.length == 61);
    bytes8 oldValue = self.valueSubmitted[theAddress];
    bytes8 newValue = self.valueWritten[theAddress];
    // verifying the proof of the old value
    bytes32 runningHash = keccak256(oldValue);
    uint64 eight = 8;
    for (uint i = 0; i < 61; i++) {
      if ((theAddress & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    require (runningHash == self.newHash);
    // find out new hash after write
    runningHash = keccak256(newValue);
    for (i = 0; i < 61; i++) {
      if ((theAddress & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    self.newHash = runningHash;
    self.writtenAddress.length = self.writtenAddress.length - 1;
    emit HashUpdated(theAddress, newValue, self.newHash);
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


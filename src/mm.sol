/// @title Partition contract
pragma solidity ^0.4.18;


contract mortal {
  address public owner;

  function mortal() public {
    owner = msg.sender;
  }

  function kill() public {
    if (msg.sender == owner) {
      selfdestruct(owner);
    }
  }
}


contract mm is mortal {
  // the privider will fill the memory for the client to read and write
  // memory starts with hash and all values that are inserted are first verified
  // then client can read inserted values and write some more
  // finally the provider has to update the hash to account for writes
  address public provider;
  address public client;
  bytes32 public initialHash;
  bytes32 public newHash;

  mapping(uint64 => bool) public addressWasSubmitted; // mark address submitted
  mapping(uint64 => bytes8) private valueSubmitted; // value submitted to address

  mapping(uint64 => bool) public addressWasWritten; // marks address as written
  mapping(uint64 => bytes8) public valueWritten; // value written to address

  uint64[] public writtenAddress;
  function getWrittenAddressLength() public constant returns(uint) {
    return writtenAddress.length;
  }

  enum state { WaitingValues, Reading, Writing, UpdatingHashes, Finished }
  state public currentState;

  event MemoryCreated(bytes32 theInitialHash);
  event ValueSubmitted(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedSubmittions();
  event FinishedReading();
  event ValueWritten(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedWriting();
  event HashUpdated(uint64 addressSubmitted, bytes8 valueSubmitted,
                    bytes32 newHash);
  event Finished();

  function mm(address theProvider, address theClient,
              bytes32 theInitialHash) public
  {
    require(theProvider != theClient);
    provider = theProvider;
    client = theClient;
    initialHash = theInitialHash;
    newHash = theInitialHash;

    currentState = state.WaitingValues;
    MemoryCreated(theInitialHash);
  }

  /// @notice Proves that a certain value in initial memory is correct
  /// @param theAddress The address of the value to be confirmed
  /// @param theValue The value in that address to be confirmed
  /// @param proof The proof that this value is correct
  function proveValue(uint64 theAddress, bytes8 theValue,
                       bytes32[] proof) public
  {
    require(msg.sender == provider);
    require(currentState == state.WaitingValues);
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
    require (runningHash == initialHash);
    addressWasSubmitted[theAddress] = true;
    valueSubmitted[theAddress] = theValue;

    ValueSubmitted(theAddress, theValue);
  }

  /// @notice Stop memory insertion and start read and write phase
  function finishSubmissionPhase() public {
    require(msg.sender == provider);
    require(currentState == state.WaitingValues);
    currentState = state.Reading;
    FinishedSubmittions();
  }

  /// @notice reads a slot in memory that has been proved to be correct
  /// according to initial hash
  /// @param theAddress of the desired memory
  function read(uint64 theAddress) public view returns (bytes8) {
    require(currentState == state.Reading);
    require((theAddress & 7) == 0);
    require(addressWasSubmitted[theAddress] == true);
    return valueSubmitted[theAddress];
  }

  /// @notice Stop read phase and start write phase
  function finishReadPhase() public {
    require(msg.sender == client);
    require(currentState == state.Reading);
    currentState = state.Writing;
    FinishedReading();
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param theAddress of the write
  /// @param theValue to be written
  function write(uint64 theAddress, bytes8 theValue) public {
    require(msg.sender == client);
    require(currentState == state.Writing);
    require((theAddress & 7) == 0);
    require(addressWasSubmitted[theAddress]);
    require(!addressWasWritten[theAddress]);
    addressWasWritten[theAddress] = true;
    valueWritten[theAddress] = theValue;
    writtenAddress.push(theAddress);
    ValueWritten(theAddress, theValue);
  }

  /// @notice Stop write phase
  function finishWritePhase() public {
    require(msg.sender == client);
    require(currentState == state.Writing);
    currentState = state.UpdatingHashes;
    FinishedWriting();
  }

  /// @notice Update hash corresponding to write
  /// @param proof The proof that the new value is correct
  function updateHash(bytes32[] proof) public {
    require(msg.sender == provider);
    require(currentState == state.UpdatingHashes);
    require(writtenAddress.length > 0);
    uint64 theAddress = writtenAddress[writtenAddress.length - 1];
    require((theAddress & 7) == 0);
    require(addressWasSubmitted[theAddress]);
    require(addressWasWritten[theAddress]);
    require(proof.length == 61);
    bytes8 oldValue = valueSubmitted[theAddress];
    bytes8 newValue = valueWritten[theAddress];
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
    require (runningHash == newHash);
    // find out new hash after write
    runningHash = keccak256(newValue);
    for (i = 0; i < 61; i++) {
      if ((theAddress & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    newHash = runningHash;
    writtenAddress.length = writtenAddress.length - 1;
    HashUpdated(theAddress, newValue, newHash);
  }

  /// @notice Finishes updating the hash
  function finishUpdateHashPhase() public {
    require(msg.sender == provider);
    require(currentState == state.UpdatingHashes);
    require(writtenAddress.length == 0);
    currentState = state.Finished;
    Finished();
  }
}


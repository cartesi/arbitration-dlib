/// @title Partition contract
pragma solidity ^0.4.18;

contract mortal {
    address public owner;

    function mortal() public { owner = msg.sender; }
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract mm is mortal {
  // the privider will fill the memory for the client to read and write
  // memory starts with hash and all values that are inserted are first verified
  // then client can read inserted values and write some more
  // finally the provider has to update the hash to account for writes
  address public provider;
  address public client;
  bytes32 initialHash;
  bytes32 finalHash;

  mapping(uint64 => bool) public addressWasSubmitted; // mark address submitted
  mapping(uint64 => uint64) public valueSubmitted; // value submitted to address

  mapping(uint64 => bool) public addressWasWritten; // marks address as written
  mapping(uint64 => uint64) public valueWritten; // value written to address

  enum state { WaitingValues, ReadAndWrite,
               UpdatingHashes, Finished }
  state public currentState;

  event MemoryCreated(bytes32 theInitialHash);
  event ValueSubmitted(uint64 addressSubmitted, uint64 valueSubmitted);
  event FinishedSubmittions();
  event ValueWritten(uint64 addressSubmitted, uint64 valueSubmitted);
  event OneHashUpdate(uint64 addressSubmitted, uint64 valueSubmitted,
                      bytes32 newHash);
  event Finished();

  function mm(address theProvider, address theClient,
              bytes32 theInitialHash) public {
    require(theProvider != theClient);
    provider = theProvider;
    client = theClient;
    initialHash = theInitialHash;

    currentState = state.WaitingValues;
    MemoryCreated(theInitialHash);
  }

  /// @notice Insert value to be verified
  /// @param theAddress The address of the value to be inserted
  /// @param theValue The value to be inserted
  /// @param proof The proof that this value is correct
  function insertValue(uint64 theAddress, uint64 theValue,
                       bytes32[] proof) public {
    require(msg.sender == provider);
    require(currentState == state.WaitingValues);
    require((theAddress & 7) == 0);
    require(proof.length == 61);
    bytes32 running_hash = keccak256(theValue);
    // iterate the hash with the uncle subtree provided in proof
    uint64 eight = 8;
    for (uint i = 0; i < 61; i++) {
      if ((theAddress & (eight << i)) == 0) {
        running_hash = keccak256(running_hash, proof[i]);
      } else {
        running_hash = keccak256(proof[i], running_hash);
      }
    }
    require (running_hash == initialHash);
    addressWasSubmitted[theAddress] = true;
    valueSubmitted[theAddress] = theValue;

    ValueSubmitted(theAddress, theValue);
  }

  /// @notice Stop memory insertion and start read and write phase
  function finishSubmissionPhase() public {
    require(msg.sender == provider);
    currentState = state.ReadAndWrite;
    FinishedSubmittions();
  }

  /// @notice reads a slot in memory that has been proved to be correct
  /// according to initial hash
  /// @param theAddress of the desired memory
  function read(uint64 theAddress) public view returns (uint64) {
    require(currentState == state.ReadAndWrite);
    require((theAddress & 7) == 0);
    require(addressWasSubmitted[theAddress] == true);
    return valueSubmitted[theAddress];
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param theAddress of the write
  /// @param theValue to be written
  //function write(uint64 theAddress, uint64 theValue) public {
  //  require(currentState == state.ReadAndWrite);
  //  require((theAddress & 7) == 0);
  //  require(msg.sender == client);
  //  create a list of changed addresses!!!
  //}
}


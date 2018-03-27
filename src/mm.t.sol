/// @title Memory manager contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./mm.sol";

contract mmTest is mortal {

  using mmLib for mmLib.mmCtx;
  mmLib.mmCtx mm;

  event MemoryCreated(bytes32 theInitialHash);
  event ValueSubmitted(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedSubmittions();
  event FinishedReading();
  event ValueWritten(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedWriting();
  event HashUpdated(uint64 addressSubmitted, bytes8 valueSubmitted,
                    bytes32 newHash);
  event Finished();

  function mmTest(address theProvider, address theClient,
                  bytes32 theInitialHash) public
  {
    mm.init(theProvider, theClient, theInitialHash);
  }

  function proveValue(uint64 theAddress, bytes8 theValue,
                      bytes32[] proof) public
  {
    mm.proveValue(theAddress, theValue, proof);
  }

  function finishSubmissionPhase() public
  {
    mm.finishSubmissionPhase();
  }

  function read(uint64 theAddress)
    public view returns (bytes8)
  {
    return mm.read(theAddress);
  }

  function write(uint64 theAddress, bytes8 theValue)
    public
  {
    mm.write(theAddress, theValue);
  }

  function finishWritePhase() public
  {
    mm.finishWritePhase();
  }

  function updateHash(bytes32[] proof) public
  {
    mm.updateHash(proof);
  }

  function finishUpdateHashPhase() public
  {
    mm.finishUpdateHashPhase();
  }

  // external interaction
  function currentState() public view returns (mmLib.state) {
    return mm.currentState;
  }

  function addressWasSubmitted(uint64 key) public view returns (bool) {
    return mm.addressWasSubmitted[key];
  }

  function writtenAddress(uint64 position) public view returns (uint64) {
    return mm.writtenAddress[position];
  }

  function valueWritten(uint64 addr) public view returns (bytes8) {
    return mm.valueWritten[addr];
  }

  function getWrittenAddressLength() public view returns (uint) {
    return mm.writtenAddress.length;
  }

  function newHash() public view returns (bytes32) {
    return mm.newHash;
  }
}


/// @title Memory manager contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./MMLib.sol";

contract MMInterface is mortal {

  using MMLib for MMLib.MMCtx;
  MMLib.MMCtx mm;

  event MemoryCreated(bytes32 theInitialHash);
  event ValueSubmitted(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedSubmittions();
  event FinishedReading();
  event ValueWritten(uint64 addressSubmitted, bytes8 valueSubmitted);
  event FinishedWriting();
  event HashUpdated(uint64 addressSubmitted, bytes8 valueSubmitted,
                    bytes32 newHash);
  event Finished();


  // Getters methods

  function provider() public view returns (address) {
    return mm.provider;
  }

  function client() public view returns (address) {
    return mm.client;
  }

  function initialHash() public view returns (bytes32) {
    return mm.initialHash;
  }

  function newHash() public view returns (bytes32) {
    return mm.newHash;
  }

  function currentState() public view returns (MMLib.state) {
    return mm.currentState;
  }

  function addressWasSubmitted(uint64 key) public view returns (bool) {
    return mm.addressWasSubmitted[key];
  }

  function valueSubmitted(uint64 key) public view returns (bytes8) {
    return mm.valueSubmitted[key];
  }

  function writtenAddress(uint64 position) public view returns (uint64) {
    return mm.writtenAddress[position];
  }

  function addressWasWritten(uint64 addr) public view returns (bool) {
    return mm.addressWasWritten[addr];
  }

  function valueWritten(uint64 addr) public view returns (bytes8) {
    return mm.valueWritten[addr];
  }

  function getWrittenAddressLength() public view returns (uint) {
    return mm.writtenAddress.length;
  }

  // Library functions

  function MMInterface(address theProvider, address theClient,
                       bytes32 theInitialHash) public
  {
    require(owner != theProvider);
    require(owner != theClient);
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
}


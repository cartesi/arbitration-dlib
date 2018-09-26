/// @title Simple Data Logger
pragma solidity 0.4.24;

contract SimpleDataLogger {
  
  mapping (bytes32 => bytes32) pastLogs;
  event HashLog(bytes32 hashId, bytes32 outputHash);
 
  //log computation with input identified by inputHash, on app identified by appHash on step step; 
  function logComputation(bytes32 inputHash, bytes32 appHash, bytes32 outputHash, uint step) public {
    bytes32 hashId = keccak256(abi.encodePacked(inputHash,appHash, step));
    pastLogs[hashId] = outputHash;
    emit HashLog(hashId, outputHash);
  }
  
  //return logged computation with inputHash, appHash on step step
  function getLog(bytes32 inputHash, bytes32 appHash, uint step) view public returns(bytes32){
    bytes32 hashId = keccak256(abi.encodePacked(inputHash,appHash, step));
    return pastLogs[hashId];
  }
}

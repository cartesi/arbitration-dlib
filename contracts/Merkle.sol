/// @title Library for Merkle proofs
pragma solidity ^0.4.24;

library Merkle {
  function getRoot(uint64 _position, bytes8 _value, bytes32[] proof)
    internal pure returns (bytes32)
  {
    require((_position & 7) == 0);
    require(proof.length == 61);
    bytes32 runningHash = keccak256(_value);
    // iterate the hash with the uncle subtree provided in proof
    uint64 eight = 8;
    for (uint i = 0; i < 61; i++) {
      if ((_position & (eight << i)) == 0) {
        runningHash = keccak256(runningHash, proof[i]);
      } else {
        runningHash = keccak256(proof[i], runningHash);
      }
    }
    return (runningHash);
  }
}

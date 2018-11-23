pragma solidity 0.4.24;

contract TestHash {

  event OutB32(bytes32 _out);
  event OutUint64(uint64 _out);

  constructor () public {}

  function testing(bytes8 c, uint64 d) public {

    uint64 a = uint64(0x0000000000000001);
    uint64 b = uint64(0x0100000000000000);

    emit OutB32(keccak256(a));
    emit OutB32(keccak256(b));
    emit OutB32(keccak256(abi.encodePacked(a, b)));
    emit OutB32(keccak256(a + b));
  }
}

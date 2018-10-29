/// @title Bits Manipulation Library

pragma solidity 0.4.24;

import "./strings.sol";

//change to lib after testing
contract BitsManipulationLibrary {
  using strings for *;

  event Print(string message);

  function littleEndianToBigEndian(uint32 num) public pure returns(uint32){
    uint32 output =
      ((num >> 24) & 0xff) |
      ((num << 8)  & 0xff0000) |
      ((num >> 8)  & 0xff00) |
      ((num << 24) & 0xff000000);
    return output;
  }
  function uint32ToBitString(uint32 num) public pure returns (string) {
    bytes memory bitString = new bytes(32);

    for (uint32 i = 0; i < 32; i++) {
      bitString[31 - i] = (num % 2 == 0) ? byte("0") : byte("1");
      num /= 2;
    }
    return string(bitString);
  }

  function bitStringToUint32(string bitString) public pure returns (uint32) {

    var s = bitString.toSlice();
    var delim = ".".toSlice();
    var bitsArray = new string[](s.count(delim) + 1);
    for(uint32 i = 0; i < bitsArray.length; i++) {
      bitsArray[i] = s.split(delim).toString();
    }

    require(bitsArray.length <= 32);
    uint32 num = 0;

    for (i = 0; i < bitsArray.length; i++) {
      num *= 2;
      //cant compare string memory and literal_string
      if (keccak256(abi.encodePacked(bitsArray[i])) == keccak256("1")) {
        num += 1;
      }else {
        require(keccak256(abi.encodePacked(bitsArray[i])) == keccak256("0"));
      }
    }
    return num;
  }
}


/// @title Bits Manipulation Library
pragma solidity 0.4.24;

import "./strings.sol";

//change to lib after testing
library BitsManipulationLibrary {
  using strings for *;

  function int32_shift_right(int32 number, uint shiftAmount)
  public returns(int32)
  {
    uint32 u_number = uint32(number);
    uint sign_bit = u_number >> 31;

    int32 output = int32((u_number >> shiftAmount) |
          (((0 - sign_bit) << 1) << (31 - shiftAmount)));

    return output;
  }

  function int64_shift_right(int64 number, uint shiftAmount)
  public returns(int64)
  {
    uint64 u_number = uint64(number);
    uint sign_bit = u_number >> 63;

    int32 output = int32((u_number >> shiftAmount) |
          (((0 - sign_bit) << 1) << (63 - shiftAmount)));

    return output;
  }

  function uint64_swapEndian(uint64 num) public pure returns(uint64){
    uint64 output =
      ((num &  0x00000000000000ff) << 56)|
      ((num &  0x000000000000ff00) << 40)|
      ((num &  0x0000000000ff0000) << 24)|
      ((num &  0x00000000ff000000) << 8) |
      ((num &  0x000000ff00000000) >> 8) |
      ((num &  0x0000ff0000000000) >> 24)|
      ((num &  0x00ff000000000000) >> 40)|
      ((num &  0xff00000000000000) >> 56);

    return output;
  }

  function uint32_swapEndian(uint32 num) public pure returns(uint32) {
    uint32 output =
      ((num >> 24) & 0xff) |
      ((num << 8)  & 0xff0000) |
      ((num >> 8)  & 0xff00) |
      ((num << 24) & 0xff000000);
    return output;
  }

  function uint32_toBitString(uint32 num) public pure returns (string) {
    bytes memory bitString = new bytes(64);

    for (uint256 i = 0; i < 63; i+=2) {
        bitString[63 - i] = ".";
        bitString[63 - (i+1)] = (num % 2 == 0) ? byte("0") : byte("1");
        num /= 2;
    }
    return string(bitString);
  }

  function bitString_toUint32(string bitString) public returns (uint32) {
    var s = bitString.toSlice();
    var delim = ".".toSlice();
    var bitsArray = new string[](s.count(delim) + 1);
    for(uint32 i = 0; i < bitsArray.length; i++) {
      bitsArray[i] = s.split(delim).toString();
    }

    return bitsArray_toUint32(bitsArray);
  }

  function int32_toBitString(int32 num) public returns (string) {
    return uint32_toBitString(uint32(num));
  }

  function bitString_toInt32(string bitString) public returns (int32) {
    return int32(bitString_toUint32(bitString));
  }

  function bitsArray_toUint32(string[] bitsArray) internal returns (uint32){
    uint32 num = 0;

    for (uint256 i = 0; i < bitsArray.length; i++) {
      num *= 2;
      //cant compare string memory and literal_string
      if (keccak256(abi.encodePacked(bitsArray[i])) == keccak256("1")) {
        num += 1;
      }
    }
    return num;
  }
}


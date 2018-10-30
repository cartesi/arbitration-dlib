/// @title Bits Manipulation Library

pragma solidity 0.4.24;

import "./strings.sol";

//change to lib after testing
contract BitsManipulationLibrary {
  using strings for *;

  event Print(string message);

  function int32_arith_shift_right(int32 number, uint shitAmount)
  public pure returns (int32)
  {
        
  }

  function uint32_littleToBigEndian(uint32 num) public pure returns(uint32) {
    uint32 output =
      ((num >> 24) & 0xff) |
      ((num << 8)  & 0xff0000) |
      ((num >> 8)  & 0xff00) |
      ((num << 24) & 0xff000000);
    return output;
  }

  function uint32_toBitString(uint32 num) public pure returns (string) {
    bytes memory bitString = new bytes(32);

    for (uint32 i = 0; i < 32; i++) {
      bitString[31 - i] = (num % 2 == 0) ? byte("0") : byte("1");
      num /= 2;
    }
    return string(bitString);
  }

  function int32_toBitString(int32 num) public pure returns (string) {
    bytes memory bitString = new bytes(32);

    bool negative = (num < 0);
    int firstOnePos = -1;

    for (uint32 i = 0; i < 32; i++) {
      if(num % 2 == 0){
        bitString[31 - i] = byte("0");
      }else{
        bitString[31 - i] = byte("1");

        if(firstOnePos < 31 - i){
          firstOnePos = 31 -i;
        }
      }
      num /= 2;
    }
    if(negative){
      for (i = 0; i < firstOnePos; i++){
        if(bitString[i] == byte("0")){
          bitString[i] = byte("1");
        }else{
          bitString[i] = byte("0");
        }
      }
    }

    return string(bitString);
  }
  function bitString_toUint32(string bitString) public pure returns (uint32) {
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


/// @title Bits Manipulation Library

pragma solidity 0.4.24;

import "./strings.sol";

//change to lib after testing
contract BitsManipulationLibrary {
  using strings for *;

  event Print(string message);

  function int32_arith_shift_right(int32 number, uint shiftAmount)
  public returns (int32)
  {
    string memory bitString = int32_toBitString(number);
    string[] memory afterShift = new string[](32);

    var s = bitString.toSlice();
    var delim = ".".toSlice();
    var bitsArray = new string[](s.count(delim) + 1);
    for(uint256 i = 0; i < bitsArray.length; i++) {
      bitsArray[i] = s.split(delim).toString();
    }

    if((keccak256(bitsArray[0]) == keccak256("1"))){
      emit Print("primeiro if");
      for(i = 0; i < shiftAmount; i++){
        emit Print("primeiro 1231if");
        afterShift[i] = "1";
      }
      for(i = shiftAmount; i <= (32 - shiftAmount); i++){
        afterShift[i] = bitsArray[i - shiftAmount];
      }

      return int32(bitsArray_toUint32(afterShift));
    }

      return number >> shiftAmount;
  }

  function uint32_swapEndian(uint32 num) public pure returns(uint32) {
    uint32 output =
      ((num >> 24) & 0xff) |
      ((num << 8)  & 0xff0000) |
      ((num >> 8)  & 0xff00) |
      ((num << 24) & 0xff000000);
    return output;
  }

  //with delimiter
  function uint32_toBitString(uint32 num) public pure returns (string) {
    bytes memory bitString = new bytes(64);

    for (uint256 i = 0; i < 63; i+=2) {
        bitString[63 - i] = ".";
        bitString[63 - (i+1)] = (num % 2 == 0) ? byte("0") : byte("1");
        num /= 2;
    }
    return string(bitString);
  }

  //delim has to be added:
  //example output: 1.0 = 2; 1.1.1 = 7;
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
//    require(bitsArray.length <= 32);
    uint32 num = 0;

    for (uint256 i = 0; i < bitsArray.length; i++) {
      num *= 2;
      //cant compare string memory and literal_string
      if (keccak256(abi.encodePacked(bitsArray[i])) == keccak256("1")) {
        num += 1;
      }else {
//        require(keccak256(abi.encodePacked(bitsArray[i])) == keccak256("0"));
      }
    }
    return num;
  }
}


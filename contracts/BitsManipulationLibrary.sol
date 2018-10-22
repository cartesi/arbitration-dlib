/// @title Bits Manipulation Library

pragma solidity 0.4.24;

library BitsManipulationLibrary {
 
  function uint32ToBitString(uint32 num) public pure returns (string) {
    bytes memory bitString = new bytes(32);

    for (uint32 i = 0; i < 32; i++) {
      bitString[31 - i] = (num % 2 == 0) ? byte("0") : byte("1");
      num /= 2;
    }
    return string(bitString);
  }

  function bitStringToUint32(bytes32 bitString) public pure returns (uint32) {
    require(bitString.length <= 32);
    uint32 num = 0;
    
    for (uint32 i = 0; i < bitString.length; i++) {
      num *= 2;
      if (bitString[i] == 0x01) {
        num += 1;
      }else {
        require(bitString[i] == 0x00);
      }
    }
    return num;
  }  

}


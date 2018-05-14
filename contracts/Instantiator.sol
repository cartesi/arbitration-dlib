/// @title Interface for memory manager instantiator
pragma solidity ^0.4.0;

contract Instantiator
{
  uint32 internal currentIndex = 0;

  modifier onlyInstantiated(uint32 _index)
  { require(currentIndex > _index); _; }
}

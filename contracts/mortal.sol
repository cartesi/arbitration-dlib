pragma solidity ^0.4.18;

contract mortal {
  address public owner;

  function mortal() public {
    owner = msg.sender;
  }

  function kill() public {
    require(msg.sender == owner);
    selfdestruct(owner);
  }
}

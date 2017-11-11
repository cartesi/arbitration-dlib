pragma solidity ^0.4.0;

contract timeAware {
  function getTime() view internal returns (uint) {
    return now;
  }
}


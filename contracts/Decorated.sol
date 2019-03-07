pragma solidity 0.4.25;

contract Decorated {
  // This contract defines several modifiers but does not use
  // them - they will be used in derived contracts.
  modifier onlyBy(address user) {
    require(msg.sender == user, "Function cannot be called by this user");
    _;
  }

  modifier onlyAfter(uint time) {
    require(now > time, "Function cannot be called now, need to wait");
    _;
  }
}

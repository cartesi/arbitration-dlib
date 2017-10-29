pragma solidity ^0.4.0;

contract mortal {
    address owner;

    function mortal() public { owner = msg.sender; }
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract greeter is mortal {
    string greeting;

    function greeter(string _greeting) public { greeting = _greeting; }
    function greet() public constant returns (string) { return greeting; }
}


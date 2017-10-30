pragma solidity ^0.4.0;

contract mortal {
    address public owner;

    function mortal() public { owner = msg.sender; }
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract greeter is mortal {
    string public greeting;
    string public greeting2;

    event ChangeGreetingEvent(string oldGreeting, string newGreeting);

    function greeter(string _greeting) public { greeting = _greeting; }
    function change(string newGreeting) public returns (string)
    { ChangeGreetingEvent(greeting, newGreeting);
      greeting = newGreeting;
    }
    function greet() public constant returns (string) { return greeting; }
}


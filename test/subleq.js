const BigNumber = require('bignumber.js');

const mm = require('../utils/mm.js');
const expect = require('chai').expect;
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;

var SimpleMemoryInterface = artifacts.require("./SimpleMemoryInterface.sol");
var SubleqInterface = artifacts.require("./SubleqInterface.sol");

var echo_binary = [-1, 21, 3,
                   21, -1, 6,
                   21, 22, 9,
                   22, 23, -1,
                   21, 21, 15,
                   22, 22, 18,
                   23, 23, 0,
                   0, 0, 0]

var input_string = [2, 4, 8, 16, 32, 64, -1];

function two_complement_32(decimal) {
  if (decimal >= 0) {
    return "0x" + ("000000000000000" + decimal.toString(16)).substr(-16);
  }
  low_bits = (decimal < 0 ? (0xFFFFFFFF + decimal + 1) : decimal).toString(16);
  return "0xffffffff" + low_bits;
};

pcPosition =     ("0x4000000000000000");
// input counter
icPosition =     ("0x4000000000000008");
// output counter
ocPosition =     ("0x4000000000000010");
// address for halted state
rSizePosition =    ("0x4000000000000020");
iSizePosition =    ("0x4000000000000028");
oSizePosition =    ("0x4000000000000030");

icInitial =      ("0x8000000000000000");
ocInitial =      ("0xc000000000000000");

contract('SubleqInterface', function(accounts) {
  it('Checking functionalities', async function() {
    // launch simpleMemory contract from accounts[2], who will be the owner
    let simpleMemoryInterface = await SimpleMemoryInterface
        .new({ from: accounts[2], gas: 2000000 });

    // check if waiting to write values
    currentState = await simpleMemoryInterface
      .currentState.call({ from: accounts[0] });
    expect(currentState.toNumber()).to.equal(0);

    // write program to memory contract
    //console.log('write program to memory contract');
    var softwareLength = echo_binary.length;
    for (let i = 0; i < softwareLength; i++) {
      // write on memory
      //console.log(two_complement_32(echo_binary[i]));
      response = await simpleMemoryInterface
        .write(8 * i, two_complement_32(echo_binary[i]),
               { from: accounts[0], gas: 1500000 })
    }

    // write ic
    response = await simpleMemoryInterface.write(icPosition, icInitial)
    // write oc
    response = await simpleMemoryInterface.write(ocPosition, ocInitial)
    // write rSize
    response = await simpleMemoryInterface
      .write(rSizePosition, "0x0000000000100000")
    // write iSize
    response = await simpleMemoryInterface
      .write(iSizePosition, "0x0000000000100000")
    // write oSize
    response = await simpleMemoryInterface
      .write(oSizePosition, "0x0000000000100000")

    // write input in memory contract
    //console.log('write input in memory contract');

    var inputLength = input_string.length;
    for (let i = 0; i < inputLength; i++) {
      // write on memory
      response = await simpleMemoryInterface
        .write(BigNumber(icInitial).plus(8 * i).toString(),
               two_complement_32(input_string[i]),
               { from: accounts[0], gas: 1500000 })
    }

    // finishing writing
    response = await simpleMemoryInterface
      .finishWritePhase({ from: accounts[0], gas: 1500000 })

    // launch subleq from accounts[2], who will be the owner
    let subleqInterface = await SubleqInterface
        .new(simpleMemoryInterface.address,
             { from: accounts[2], gas: 2000000 });

    // check if waiting to read values
    currentState = await simpleMemoryInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(1);

    let running = 0;

    while (running === 0) {
      // print machine state for debugging
      // response = await simpleMemoryInterface
      //   .read(pcPosition)
      //   .call({ from: accounts[0], gas: 1500000 });
      // console.log("pc = " + response);
      // for (let j = 0; j < 10; j++) {
      //   response = await simpleMemoryInterface
      //     .read(8 * j)
      //     .call({ from: accounts[0], gas: 1500000 });
      //   console.log("hd at: " + j + " = " + response);
      // }
      // for (let j = 0; j < 10; j++) {
      //   response = await simpleMemoryInterface
      //     .read(BigNumber(icInitial).add(8 * j))
      //     .call({ from: accounts[0], gas: 1500000 });
      //   console.log("input at: " + j + " = " + response);
      // }
      // for (let j = 0; j < 10; j++) {
      //   response = await simpleMemoryInterface
      //     .read(BigNumber(ocInitial).add(8 * j))
      //     .call({ from: accounts[0], gas: 1500000 });
      //   console.log("output at: " + j + " = " + response);
      // }
      // console.log(await subleqInterface.owner());
      // console.log(accounts[2]);

      response = await subleqInterface.step({ from: accounts[2], gas: 1500000 })
      expect(getEvent(response, 'StepGiven')).not.to.be.undefined;
      // console.log(getEvent(response, 'StepGiven'));

      running = getEvent(response, 'StepGiven').exitCode.toNumber();
      //console.log(running);
    }
    expect(running).to.equal(7);

    let j = 0;
    // verifying output
    while (true) {
      response = await simpleMemoryInterface
        .read.call(BigNumber(ocInitial).plus(8 * j).toString(),
                   { from: accounts[0], gas: 1500000 });
      //console.log(response);
      expect(response).to.equal(two_complement_32(input_string[j]));
      if (response == '0xffffffffffffffff') break;
      j++;
    }

    // kill contracts
    response = await simpleMemoryInterface
      .kill({ from: accounts[2], gas: 1500000 });
    response = await subleqInterface
      .kill({ from: accounts[2], gas: 1500000 });

    // check if contracts were killed
    [error, currentState] = await unwrap(simpleMemoryInterface.currentState());
    expect(error.message).to.have.string('not a contract address');;
    [error, currentState] = await unwrap(subleqInterface.step());
    expect(error.message).to.have.string('not a contract address');;
  });
});

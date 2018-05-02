const BigNumber = require('bignumber.js');

const mm = require('../utils/mm.js');
const expect = require('chai').expect;
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;
const twoComplement32 = require('../utils/tools.js').twoComplement32;

var SubleqInterface = artifacts.require("./SubleqInterface.sol");
var SimpleMemoryInstantiator = artifacts.require("./SimpleMemoryInstantiator.sol");

contract('SubleqInterface', function(accounts) {
  let echo_binary = [-1, 21, 3,
                     21, -1, 6,
                     21, 22, 9,
                     22, 23, -1,
                     21, 21, 15,
                     22, 22, 18,
                     23, 23, 0,
                     0, 0, 0]

  let input_string = [2, 4, 8, 16, 32, 64, -1];


  let pcPosition =     ("0x4000000000000000");
  // input counter
  let icPosition =     ("0x4000000000000008");
  // output counter
  let ocPosition =     ("0x4000000000000010");
  // address for halted state
  let rSizePosition =    ("0x4000000000000020");
  let iSizePosition =    ("0x4000000000000028");
  let oSizePosition =    ("0x4000000000000030");

  let icInitial =      ("0x8000000000000000");
  let ocInitial =      ("0xc000000000000000");

  let mmAddress;

  it('Checking functionalities', async function() {
    // launch simpleMemory contract from accounts[2], who will be the owner
    let simpleMemoryInstantiator = await SimpleMemoryInstantiator
        .new({ from: accounts[2], gas: 2000000 });
    mmAddress = simpleMemoryInstantiator.address;

    // write program to memory contract
    //console.log('write program to memory contract');
    var softwareLength = echo_binary.length;
    for (let i = 0; i < softwareLength; i++) {
      // write on memory
      //console.log(twoComplement32(echo_binary[i]));
      response = await simpleMemoryInstantiator
        .write(0, 8 * i, twoComplement32(echo_binary[i]),
               { from: accounts[0], gas: 1500000 })
    }

    // write ic
    response = await simpleMemoryInstantiator.write(0, icPosition, icInitial)
    // write oc
    response = await simpleMemoryInstantiator.write(0, ocPosition, ocInitial)
    // write rSize
    response = await simpleMemoryInstantiator
      .write(0, rSizePosition, "0x0000000000100000")
    // write iSize
    response = await simpleMemoryInstantiator
      .write(0, iSizePosition, "0x0000000000100000")
    // write oSize
    response = await simpleMemoryInstantiator
      .write(0, oSizePosition, "0x0000000000100000")

    // write input in memory contract
    //console.log('write input in memory contract');

    var inputLength = input_string.length;
    for (let i = 0; i < inputLength; i++) {
      // write on memory
      response = await simpleMemoryInstantiator
        .write(0, BigNumber(icInitial).plus(8 * i).toString(),
               twoComplement32(input_string[i]),
               { from: accounts[0], gas: 1500000 })
    }

    // launch subleq from accounts[2], who will be the owner
    let subleqInterface = await SubleqInterface
        .new(simpleMemoryInstantiator.address,
             { from: accounts[2], gas: 2000000 });

    let running = 0;

    while (running === 0) {
      // print machine state for debugging
      // response = await simpleMemoryInstantiator
      //   .read(pcPosition)
      //   .call({ from: accounts[0], gas: 1500000 });
      // console.log("pc = " + response);
      // for (let j = 0; j < 10; j++) {
      //   response = await simpleMemoryInstantiator
      //     .read(8 * j)
      //     .call({ from: accounts[0], gas: 1500000 });
      //   console.log("hd at: " + j + " = " + response);
      // }
      // for (let j = 0; j < 10; j++) {
      //   response = await simpleMemoryInstantiator
      //     .read(BigNumber(icInitial).add(8 * j))
      //     .call({ from: accounts[0], gas: 1500000 });
      //   console.log("input at: " + j + " = " + response);
      // }
      // for (let j = 0; j < 10; j++) {
      //   response = await simpleMemoryInstantiator
      //     .read(BigNumber(ocInitial).add(8 * j))
      //     .call({ from: accounts[0], gas: 1500000 });
      //   console.log("output at: " + j + " = " + response);
      // }
      // console.log(await subleqInterface.owner());
      // console.log(accounts[2]);

      //
      response = await subleqInterface.step(
        mmAddress, 0,
        { from: accounts[2], gas: 1500000 })
      expect(getEvent(response, 'StepGiven')).not.to.be.undefined;
      // console.log(getEvent(response, 'StepGiven'));

      running = getEvent(response, 'StepGiven').exitCode.toNumber();
      //console.log(running);
    }
    expect(running).to.equal(7);

    let j = 0;
    // verifying output
    while (true) {
      response = await simpleMemoryInstantiator
        .read.call(0, BigNumber(ocInitial).plus(8 * j).toString(),
                   { from: accounts[0], gas: 1500000 });
      //console.log(response);
      expect(response).to.equal(twoComplement32(input_string[j]));
      if (response == '0xffffffffffffffff') break;
      j++;
    }
  });
});

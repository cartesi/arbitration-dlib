const BigNumber = require('bignumber.js');

const mm = require('../utils/mm.js');
const expect = require('chai').expect;
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;

var SimpleMemoryInterface = artifacts.require("./SimpleMemoryInterface.sol");

contract('SimpleMemoryInterface', function(accounts) {
  it('Checking functionalities', async function() {
    // launch contract from accounts[2], who will be the owner
    let simpleMemoryInterface = await SimpleMemoryInterface
        .new({ from: accounts[2], gas: 2000000 });

    // only owner should be able to kill contract
    expect(await getError(
      simpleMemoryInterface.kill({ from: accounts[0], gas: 2000000 }))
          ).to.have.string('VM Exception');

    // prepare memory
    let values = { '0':                    '0x0000000000300000',
                   '18446744073709551608': '0x00000000000f0000',
                   '1808':                 '0x000000000000c000'
                 };

    // check if waiting to write values
    currentState = await simpleMemoryInterface.currentState.call(0);
    expect(currentState.toNumber()).to.equal(0);

    // write values in initial memory
    for (key in values) {
      // write value on memory
      response = await simpleMemoryInterface
        .write(0, key, values[key], { from: accounts[0], gas: 1500000 });
    }

    // cannot submit un-aligned address
    expect(await getError(
      simpleMemoryInterface.write(0, 4, '0x0000000000000000',
                                  { from: accounts[0], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // finishing writing
    response = await simpleMemoryInterface
      .finishWritePhase(0, { from: accounts[0], gas: 1500000 })

    // check if read phase
    currentState = await simpleMemoryInterface.currentState.call(0);
    expect(currentState.toNumber()).to.equal(1);

    for (key in values) {
      // reading values on memory manager contract
      response = await simpleMemoryInterface
        .read.call(0, key, { from: accounts[0], gas: 1500000 });
      expect(response).to.equal(values[key].toString());
    }

    // write some more
    write_values = { '283888':        '0x0000000000000000',
                     '1808':          '0x0000f000f0000000',
                     '2838918800':    '0xffffffffffffffff'
                   };
    // write values in mm
    for (key in write_values) {
      // write values to memory manager contract
      response = await simpleMemoryInterface
        .write(0, key, write_values[key],
               { from: accounts[0], gas: 1500000 })
    }

    // finishing write phase
    response = await simpleMemoryInterface
      .finishWritePhase(0, { from: accounts[0], gas: 1500000 })

    // check if read phase again
    currentState = await simpleMemoryInterface.currentState.call(0);
    expect(currentState.toNumber()).to.equal(1);

    // check reading again
    for (key in write_values) {
      // reading values on memory manager contract
      response = await simpleMemoryInterface
        .read.call(0, key, { from: accounts[0], gas: 1500000 });
      expect(response).to.equal(write_values[key].toString());
    }

    // kill contract
    response = await simpleMemoryInterface.kill(
      { from: accounts[2], gas: 1500000 });

    // check if contract was killed
    [error, currentState] = await unwrap(simpleMemoryInterface.currentState(0));
    expect(error.message).to.have.string('not a contract address');;
  });
});

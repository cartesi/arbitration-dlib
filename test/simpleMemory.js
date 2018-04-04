const mm = require('../utils/mm.js');
const BigNumber = require('bignumber.js');

var expect = require('chai').expect;
var getEvent = require('../utils/tools.js').getEvent;
var unwrap = require('../utils/tools.js').unwrap;
var shouldThrow = require('../utils/tools.js').shouldThrow;

var SimpleMemoryInterface = artifacts.require("./SimpleMemoryInterface.sol");

contract('SimpleMemoryInterface', function(accounts) {
  it('Checking functionalities', async function() {
    // launch contract from account[2], who will be the owner
    let simpleMemoryInterface = await SimpleMemoryInterface
        .new({ from: accounts[2], gas: 2000000 });

    // only owner should be able to kill contract
    shouldThrow(simpleMemoryInterface.kill({ from: accounts[0], gas: 2000000 }));

    // prepare memory
    let values = { '0':                    '0x0000000000300000',
                   '18446744073709551608': '0x00000000000f0000',
                   '1808':                 '0x000000000000c000'
                 };

    /*
    // check if waiting to write values
    currentState = yield testMemoryContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('0');

    // write values in initial memory
    for (key in values) {
      // write value on memory
      response = yield testMemoryContract.methods
        .write(key, values[key])
        .send({ from: aliceAddr, gas: 1500000 })
        .on('receipt');
    }

    // cannot submit un-aligned address
    response = yield testMemoryContract.methods
      .write(4, '0x0000000000000000')
      .send({ from: aliceAddr, gas: 1500000 })
      .catch(function(error) {
        expect(error.message).to.have.string('VM Exception');
      });

    // finishing writing
    response = yield testMemoryContract.methods
      .finishWritePhase()
      .send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // check if read phase
    currentState = yield testMemoryContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('1');

    for (key in values) {
      // reading values on memory manager contract
      response = yield testMemoryContract.methods
        .read(key)
        .call({ from: aliceAddr, gas: 1500000 });
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
      response = yield testMemoryContract.methods
        .write(key, write_values[key])
        .send({ from: aliceAddr, gas: 1500000 })
        .on('receipt');
    }

    // finishing write phase
    response = yield testMemoryContract.methods
      .finishWritePhase()
      .send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // check if read phase again
    currentState = yield testMemoryContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('1');

    // check reading again
    for (key in write_values) {
      // reading values on memory manager contract
      response = yield testMemoryContract.methods
        .read(key)
        .call({ from: aliceAddr, gas: 1500000 });
      expect(response).to.equal(write_values[key].toString());
    }

    // kill contract
    response = yield testMemoryContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
      */
  });
});

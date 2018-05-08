const BigNumber = require('bignumber.js');

const mm = require('../utils/mm.js');
const expect = require('chai').expect;
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;

var SimpleMemoryInstantiator = artifacts.require("./SimpleMemoryInstantiator.sol");

contract('SimpleMemoryInstantiator', function(accounts) {
  it('Checking functionalities', async function() {
    // launch contract from accounts[2], who will be the owner
    let simpleMemoryInstantiator = await SimpleMemoryInstantiator
        .new({ from: accounts[2], gas: 2000000 });

    // prepare memory
    let values = { '0':                    '0x0000000000300000',
                   '18446744073709551608': '0x00000000000f0000',
                   '1808':                 '0x000000000000c000'
                 };

    // write values in initial memory
    for (key in values) {
      // write value on memory
      response = await simpleMemoryInstantiator
        .write(0, key, values[key], { from: accounts[0], gas: 1500000 });
    }

    // cannot submit un-aligned address
    expect(await getError(
      simpleMemoryInstantiator.write(0, 4, '0x0000000000000000',
                                  { from: accounts[0], gas: 1500000 }))
          ).to.have.string('VM Exception');
    // finishing writing
    response = await simpleMemoryInstantiator
      .finishProofPhase(0, { from: accounts[0], gas: 1500000 })

    for (key in values) {
      // reading values on memory manager contract
      response = await simpleMemoryInstantiator
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
      response = await simpleMemoryInstantiator
        .write(0, key, write_values[key],
               { from: accounts[0], gas: 1500000 })
    }

    // finishing write phase
    response = await simpleMemoryInstantiator
      .finishReplayPhase(0, { from: accounts[0], gas: 1500000 })

    // check reading again
    for (key in write_values) {
      // reading values on memory manager contract
      response = await simpleMemoryInstantiator
        .read.call(0, key, { from: accounts[0], gas: 1500000 });
      expect(response).to.equal(write_values[key].toString());
    }
 });
});

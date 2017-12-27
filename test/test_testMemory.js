const fs = require('fs');
const solc = require('solc');
const Web3 = require('web3');
const TestRPC = require("ethereumjs-testrpc");
const mocha = require('mocha')
const coMocha = require('co-mocha')
const mm = require('../utils/mm.js')
const BigNumber = require('bignumber.js');

expect = require('chai').expect;

coMocha(mocha)

aliceKey = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d'

aliceAddr = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'

// compile contract
const contractSource = fs.readFileSync('src/testMemory.sol').toString();

// using solc package for node
const compiledContract = solc.compile(contractSource, 1);
expect(compiledContract.errors, compiledContract.errors).to.be.undefined;
const bytecode = compiledContract.contracts[':testMemory'].bytecode;
const abi = JSON.parse(compiledContract.contracts[':testMemory'].interface);

function hashWord(word) {
    return web3.utils.soliditySha3({type: 'uint64', value: word});
}

describe('Testing testMemory contract', function() {
  it('Checking functionalities', function*() {
    this.timeout(150000)
    // testrpc
    var testrpcParameters = {
      "accounts":
      [   { "balance": 100000000000000000000,
            "secretKey": aliceKey }
      ]
    }
    web3 = new Web3(TestRPC.provider(testrpcParameters));

    // create contract object
    testMemoryContract = new web3.eth.Contract(abi);

    // prepare memory
    let values = { '0':                    '0x0000000000300000',
                   '18446744073709551608': '0x00000000000f0000',
                   '1808':                 '0x000000000000c000'
                 };

    // deploy contract and update object
    testMemoryContract = yield testMemoryContract.deploy({
      data: bytecode,
      arguments: []
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

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

    // finishing read phase
    response = yield testMemoryContract.methods
      .finishReadPhase()
      .send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // check if write phase
    currentState = yield testMemoryContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('0');

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
  });
});

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
machineKey = '0x6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1'

aliceAddr = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
machineAddr = '0xffcf8fdee72ac11b5c542428b35eef5769c409f0'

// compile contract
const contractSource = fs.readFileSync('src/mm.sol').toString();

// using solc package for node
const compiledContract = solc.compile(contractSource, 1);
expect(compiledContract.errors, compiledContract.errors).to.be.undefined;
const bytecode = compiledContract.contracts[':mm'].bytecode;
const abi = JSON.parse(compiledContract.contracts[':mm'].interface);

function hashWord(word) {
    return web3.utils.soliditySha3({type: 'uint64', value: word});
}

describe('Testing memory manager contract', function() {
  it('Checking functionalities', function*() {
    this.timeout(150000)
    // testrpc
    var testrpcParameters = {
      "accounts":
      [   { "balance": 100000000000000000000,
            "secretKey": aliceKey },
          { "balance": 100000000000000000000,
            "secretKey": machineKey }
      ]
    }
    web3 = new Web3(TestRPC.provider(testrpcParameters));

    // promisify jsonRPC direct call
    // sendRPC = function(param){
    //   return new Promise(function(resolve, reject){
    //     web3.currentProvider.sendAsync(param, function(err, data){
    //       if(err !== null) return reject(err);
    //       resolve(data);
    //     });
    //   });
    // }

    // create contract object
    mmContract = new web3.eth.Contract(abi);

    // prepare memory
    let myMM = new mm.MemoryManager();
    let zeros = myMM.merkel();
    let small = BigNumber('120')
    let large = BigNumber('18446744073709551608');
    let large_string = large.toString();

    let values = { '0': 1,
                   '18446744073709551608': 1,
                   '1808': 193284
                 };

    for (key in values) {
      myMM.setValue(key, values[key])
    }
    initialHash = myMM.merkel()

    // deploy contract and update object
    mmContract = yield mmContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, machineAddr, initialHash]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // check if waiting values
    currentState = yield mmContract.methods
        .currentState().call({ from: aliceAddr });
      expect(currentState).to.equal('0');

    // insert values in memory
    for (key in values) {
      // check that key was not marked as submitted
      wasSubmitted = yield mmContract.methods
        .addressWasSubmitted(key)
        .call({ from: machineAddr, gas: 1500000 });
      expect(wasSubmitted).to.be.false;
      // generate proof of value
      let proof = myMM.generateProof(key);
      // inserting values on memory manager contract
      response = yield mmContract.methods
        .insertValue(key, values[key], proof)
        .send({ from: aliceAddr, gas: 1500000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueSubmitted).not.to.be.undefined;
        });
      returnValues = response.events.ValueSubmitted.returnValues;
      // check that key was marked as submitted
      wasSubmitted = yield mmContract.methods
        .addressWasSubmitted(key)
        .call({ from: machineAddr, gas: 1500000 });
      expect(wasSubmitted).to.be.true;
    }

    other_values = { '283888': '0',
                     '282343888': '0',
                     '2838918800': '0',
                   };

    // insert some more (not inserted in myMM)
    for (key in other_values) {
      // generate proof of value
      let proof = myMM.generateProof(key);
      // inserting values on memory manager contract
      response = yield mmContract.methods
        .insertValue(key, other_values[key], proof)
        .send({ from: aliceAddr, gas: 1500000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueSubmitted).not.to.be.undefined;
        });
      returnValues = response.events.ValueSubmitted.returnValues;
      //console.log(returnValues);
    }

    // cannot submit un-aligned address
    let proof = myMM.generateProof(0);
    response = yield mmContract.methods
      .insertValue(2, 0, proof)
      .send({ from: aliceAddr, gas: 1500000 })
      .catch(function(error) {
        expect(error.message).to.have.string('VM Exception');
      });

    // finishing submissions
    response = yield mmContract.methods
      .finishSubmissionPhase()
      .send({ from: aliceAddr, gas: 1500000 })
      .on('receipt', function(receipt) {
        expect(receipt.events.FinishedSubmittions).not.to.be.undefined;
      });

    // check if read phase
    currentState = yield mmContract.methods
        .currentState().call({ from: aliceAddr });
      expect(currentState).to.equal('1');

    for (key in values) {
      // check that it waas submitted
      wasSubmitted = yield mmContract.methods
        .addressWasSubmitted(key)
        .call({ from: machineAddr, gas: 1500000 });
      // reading values on memory manager contract
      response = yield mmContract.methods
        .read(key)
        .call({ from: machineAddr, gas: 1500000 });
      expect(response).to.equal(values[key].toString());
    }

    // finishing read phase
    response = yield mmContract.methods
      .finishReadPhase()
      .send({ from: machineAddr, gas: 1500000 })
      .on('receipt', function(receipt) {
        expect(receipt.events.FinishedReading).not.to.be.undefined;
      });

    // check if write phase
    currentState = yield mmContract.methods
        .currentState().call({ from: aliceAddr });
      expect(currentState).to.equal('2');

    write_values = { '283888': '0',
                     '1808': 193284,
                     '2838918800': '0',
                   };
    // write values in mm
    for (key in write_values) {
      // write values to memory manager contract
      response = yield mmContract.methods
        .write(key, write_values[key])
        .send({ from: machineAddr, gas: 1500000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueWritten).not.to.be.undefined;
        });
      returnValues = response.events.ValueWritten.returnValues;
    }



    // kill contract
    response = yield mmContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
  });
});




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
    this.timeout(15000)
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

    for (key in values) {
      // generate proof of value
      let proof = myMM.generateProof(key);
      //console.log('proof for ' + key + ': ' + values[key]);

      // inserting values on memory manager contract
      response = yield mmContract.methods
        .insertValue(key, values[key], proof)
        .send({ from: aliceAddr, gas: 1500000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueSubmitted).not.to.be.undefined;
        });
      returnValues = response.events.ValueSubmitted.returnValues;
      //console.log(returnValues);
    }

    other_values = { '283888': '0',
                     '282343888': '0',
                     '2838918800': '0',
                   };

    for (key in other_values) {
      // generate proof of value
      let proof = myMM.generateProof(key);
      //console.log('proof for ' + key + ': ' + values[key]);

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

    //console.log("sha  0: " + hashWord(0));
    //let b = (web3.utils.sha3(hashWord(0) + hashWord(0).replace(/^0x/, '')));
    //console.log("sha 00: " + b);
    //console.log(proof);


    //  response = yield mmContract.methods
    //    .replyQuery(queryArray, replyArray)
    //    .send({ from: aliceAddr, gas: 1500000 })
    //    .catch(function(error) {
    //      expect(error.message).to.have.string('VM Exception');
    //    });

    // kill contract
    response = yield mmContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
  });
});




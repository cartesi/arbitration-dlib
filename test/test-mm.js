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
var input = {
  'src/mm.sol': fs.readFileSync('src/mm.sol', 'utf8'),
  'src/mortal.sol': fs.readFileSync('src/mortal.sol', 'utf8'),
  'src/mm.t.sol': fs.readFileSync('src/mm.t.sol', 'utf8')
};

// using solc package for node
const compiledContract = solc.compile({ sources: input }, 1);
expect(compiledContract.errors, compiledContract.errors).to.be.undefined;

const mmLibBytecode = compiledContract.contracts['src/mm.sol:mmLib'].bytecode;
const mmLibAbi = JSON.parse(compiledContract.contracts['src/mm.sol:mmLib'].interface);

var mmTestBytecode = compiledContract.contracts['src/mm.t.sol:mmTest'].bytecode;
const mmTestAbi = JSON.parse(compiledContract.contracts['src/mm.t.sol:mmTest'].interface);

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
    mmLibContract = new web3.eth.Contract(mmLibAbi);
    // create contract object
    mmTestContract = new web3.eth.Contract(mmTestAbi);

    // prepare memory
    let myMM = new mm.MemoryManager();
    let zeros = myMM.merkel();
    let small = BigNumber('120')
    let large = BigNumber('18446744073709551608');
    let large_string = large.toString();

    let values = { '0':                    '0x0000000000300000',
                   '18446744073709551608': '0x00000000000f0000',
                   '1808':                 '0x000000000000c000'
                 };

    for (key in values) {
      myMM.setValue(key, values[key])
    }
    initialHash = myMM.merkel()

    // deploy library and update object
    mmLibContract = yield mmLibContract.deploy({
      data: mmLibBytecode,
      arguments: []
    }).send({ from: aliceAddr, gas: 2000000 })
      .on('receipt');

    mmLibAddress = mmLibContract.options.address;

    var re = new RegExp('__src/mm.sol:mmLib______________________', 'g');
    mmTestBytecode = mmTestBytecode.replace(re, mmLibAddress.substr(2));
    // deploy contract and update object
    mmTestContract = yield mmTestContract.deploy({
      data: mmTestBytecode,
      arguments: [aliceAddr, machineAddr, initialHash]
    }).send({ from: aliceAddr, gas: 2000000 })
      .on('receipt');

      //.send({ from: aliceAddr, gas: 2000000 })
      //.on('receipt');
    // this line should leave after they fix this bug
    // https://github.com/ethereum/web3.js/issues/1266
    mmTestContract.setProvider(web3.currentProvider)

    // check if waiting values
    currentState = yield mmTestContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('0');

    // prove that the values in initial memory are correct
    for (key in values) {
      // check that key was not marked as submitted
      wasSubmitted = yield mmTestContract.methods
        .addressWasSubmitted(key)
        .call({ from: machineAddr, gas: 2000000 });
      expect(wasSubmitted).to.be.false;
      // generate proof of value
      let proof = myMM.generateProof(key);
      // proving values on memory manager contract
      response = yield mmTestContract.methods
        .proveValue(key, values[key], proof)
        .send({ from: aliceAddr, gas: 2000000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueSubmitted).not.to.be.undefined;
        });
      returnValues = response.events.ValueSubmitted.returnValues;
      // check that key was marked as submitted
      wasSubmitted = yield mmTestContract.methods
        .addressWasSubmitted(key)
        .call({ from: machineAddr, gas: 2000000 });
      expect(wasSubmitted).to.be.true;
    }

    other_values = { '283888':       '0x0000000000000000',
                     '282343888':    '0x0000000000000000',
                     '2838918800':   '0x0000000000000000'
                   };

    // prove some more (some that were not inserted in myMM)
    for (key in other_values) {
      // generate proof of value
      let proof = myMM.generateProof(key);
      // prove values on memory manager contract
      response = yield mmTestContract.methods
        .proveValue(key, other_values[key], proof)
        .send({ from: aliceAddr, gas: 2000000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueSubmitted).not.to.be.undefined;
        });
      returnValues = response.events.ValueSubmitted.returnValues;
      //console.log(returnValues);
    }

    // cannot submit un-aligned address
    let proof = myMM.generateProof(0);
    response = yield mmTestContract.methods
      .proveValue(4, '0x0000000000000000', proof)
      .send({ from: aliceAddr, gas: 2000000 })
      .catch(function(error) {
        expect(error.message).to.have.string('VM Exception');
      });
    // finishing submissions
    response = yield mmTestContract.methods
      .finishSubmissionPhase()
      .send({ from: aliceAddr, gas: 2000000 })
      .on('receipt', function(receipt) {
        expect(receipt.events.FinishedSubmittions).not.to.be.undefined;
      });

    // check if read phase
    currentState = yield mmTestContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('1');
    for (key in values) {
      // check that it waas submitted
      wasSubmitted = yield mmTestContract.methods
        .addressWasSubmitted(key)
        .call({ from: machineAddr, gas: 2000000 });
      // reading values on memory manager contract
      response = yield mmTestContract.methods
        .read(key)
        .call({ from: machineAddr, gas: 2000000 });
      expect(response).to.equal(values[key].toString());
    }
    write_values = { '283888':        '0x0000000000000000',
                     '1808':          '0x0000f000f0000000',
                     '2838918800':    '0xffffffffffffffff'
                   };
    // write values in mm
    for (key in write_values) {
      // write values to memory manager contract
      response = yield mmTestContract.methods
        .write(key, write_values[key])
        .send({ from: machineAddr, gas: 2000000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueWritten).not.to.be.undefined;
        });
      returnValues = response.events.ValueWritten.returnValues;
    }

    // finishing write phase
    response = yield mmTestContract.methods
      .finishWritePhase()
      .send({ from: machineAddr, gas: 2000000 })
      .on('receipt', function(receipt) {
        expect(receipt.events.FinishedWriting).not.to.be.undefined;
      });

    // check if update hash phase
    currentState = yield mmTestContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('3');

    // check how many values were writen
    sizeWriteArray = yield mmTestContract.methods
      .getWrittenAddressLength().call({ from: aliceAddr });
    // update each hash
    for(let i = sizeWriteArray - 1; i >=0; i--) {
      // address writen
      addressWritten = yield mmTestContract.methods
        .writtenAddress(i).call({ from: aliceAddr });
      //console.log(addressWritten);
      oldValue = myMM.getWord(addressWritten);
      newValue = yield mmTestContract.methods
        .valueWritten(addressWritten).call({ from: aliceAddr });
      proof = myMM.generateProof(addressWritten);
      response = yield mmTestContract.methods
        .updateHash(proof)
        .send({ from: aliceAddr, gas: 2000000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.HashUpdated).not.to.be.undefined;
        });
      returnValues = response.events.HashUpdated.returnValues;
      expect(returnValues.valueSubmitted).to.equal(newValue);
      myMM.setValue(addressWritten, newValue);
    }

    finalHash = myMM.merkel();
    remoteFinalHash = yield mmTestContract.methods
      .newHash().call({ from: aliceAddr });
    expect(finalHash).to.equal(remoteFinalHash);

    // finishing update hash phase
    response = yield mmTestContract.methods
      .finishUpdateHashPhase()
      .send({ from: aliceAddr, gas: 2000000 })
      .on('receipt', function(receipt) {
        expect(receipt.events.Finished).not.to.be.undefined;
      });

    // check if we are at the finished phase
    currentState = yield mmTestContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('4');

    // kill contract
    response = yield mmTestContract.methods.kill()
      .send({ from: aliceAddr, gas: 2000000 });
  });
});




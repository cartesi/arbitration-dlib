const fs = require('fs');
const solc = require('solc');
const Web3 = require('web3');
const TestRPC = require("ethereumjs-testrpc");
const mocha = require('mocha')
const coMocha = require('co-mocha')

const mm = require('../utils/mm.js')

expect = require('chai').expect;

coMocha(mocha)

aliceKey = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d'
bobKey = '0x6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1'

aliceAddr = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
bobAddr = '0xffcf8fdee72ac11b5c542428b35eef5769c409f0'

// compile contract
const contractSource = fs.readFileSync('src/depth.sol').toString();

// using solc package for node
const compiledContract = solc.compile(contractSource, 1);
expect(compiledContract.errors, compiledContract.errors).to.be.undefined;
const bytecode = compiledContract.contracts[':depth'].bytecode;
const abi = JSON.parse(compiledContract.contracts[':depth'].interface);

// using solc from the command line
// const { exec } = require('child_process');
// exec('/home/cortex/solidity/build/solc/solc -o /home/cortex/project/contracts --abi --bin /home/cortex/contracts/src/partition.sol', (err, stdout, stderr) => {
//     if (err) { console.log('Error compiling contract'); return; }
//     console.log(`stdout: ${stdout}`);
//     console.log(`stderr: ${stderr}`);
// });
// const bytecode = fs.readFileSync('src/partition.bin').toString();
// const abi = JSON.parse(fs.readFileSync('src/partition.abi').toString());

describe('Testing depth contract', function() {
  beforeEach(function() {
    this.timeout(15000)
    // testrpc
    var testrpcParameters = {
      "accounts":
      [   { "balance": 100000000000000000000,
            "secretKey": aliceKey },
          { "balance": 100000000000000000000,
            "secretKey": bobKey }
      ]
    }
    web3 = new Web3(TestRPC.provider(testrpcParameters));

    // promisify jsonRPC direct call
    sendRPC = function(param){
      return new Promise(function(resolve, reject){
        web3.currentProvider.sendAsync(param, function(err, data){
          if(err !== null) return reject(err);
          resolve(data);
        });
      });
    }

    let aliceMM = new mm.MemoryManager();
    let bobMM = new mm.MemoryManager();
    let zero = BigNumber('0')
    let small = BigNumber('1024')
    let large = BigNumber('18446744073709551360');

    values = { zero: 7771,
               zero.add(64): 7772,
               zero.add(128): 7773,
               zero.add(192): 7774,
               small: 2221,
               small.add(64): 2222,
               small.add(128): 2223,
               small.add(192): 2224,
               large: 3331,
               large.add(64): 3332,
               large.add(128): 3333,
               large.add(192): 3334
             };
    for (key in values) {
      aliceMM.setValue(key, values[key]);
      bobMM.setValue(key, values[key]);
    }
    bobMM.setValue(large.add(64), 3333);

    roundDuration = 3600;

    // create contract object
    depthContract = new web3.eth.Contract(abi);
  });

  it('Find divergence', function*() {
    this.timeout(15000)

    // deploy contract and update object
    depthContract = yield depthContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, bobAddr, bobMM.merkel(), roundDuration]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    while (true) {
      var i;
      // check if the state is WaitingHashes
      currentState = yield depthContract.methods
        .currentState().call({ from: bobAddr });
      expect(currentState).to.equal('1');

      currentAddress = yield depthContract.methods
        .currentAddress().call({ from: bobAddr });

      currentAddress = BigNumber(currentAddress);

      currentDepth = yield depthContract.methods
        .currentDepth().call({ from: bobAddr });

      // get the hashes of children and prepare response
      let leftHash = bobMM.subMerkel(bobMM, currentAddress,
                                     63 - currentDepth);
      let leftHash = bobMM.subMerkel(bobMM, currentAddress.add(???),
                                     63 - currentDepth);

      // sending hashes from alice should fail
      response = yield depthContract.methods
        .replyQuery(queryArray, replyArray)
        .send({ from: aliceAddr, gas: 1500000 })
        .catch(function(error) {
          expect(error.message).to.have.string('VM Exception');
        });

      // alice claiming victory should fail
      response = yield depthContract.methods
        .claimVictoryByTime()
        .send({ from: aliceAddr, gas: 1500000 })
        .catch(function(error) {
          expect(error.message).to.have.string('VM Exception');
        });

      // send hashes
      response = yield depthContract.methods
        .replyQuery(queryArray, replyArray)
        .send({ from: bobAddr, gas: 1500000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.HashesPosted).not.to.be.undefined;
        });
      returnValues = response.events.HashesPosted.returnValues;

      // find first last time of query where there was aggreement
      var lastConsensualQuery = 0;
      for (i = 0; i < querySize - 1; i++){
        if (aliceHistory[returnValues.thePostedTimes[i]]
            == returnValues.thePostedHashes[i]) {
          lastConsensualQuery = i;
        } else {
          break;
        }
      }

      // check if the state is WaitingQuery
      currentState = yield depthContract.methods
        .currentState().call({ from: bobAddr });
      expect(currentState).to.equal('0');

      // bob claiming victory should fail
      response = yield depthContract.methods
        .claimVictoryByTime()
        .send({ from: bobAddr, gas: 1500000 })
        .catch(function(error) {
          expect(error.message).to.have.string('VM Exception');
        });

      leftPoint = returnValues.thePostedTimes[lastConsensualQuery];
      rightPoint = returnValues.thePostedTimes[lastConsensualQuery + 1];

      // check if the interval is unitary
      if (+rightPoint == +leftPoint + 1) {
        // if the interval is unitary, present divergence
        response = yield depthContract.methods
          .presentDivergence(leftPoint)
          .send({ from: aliceAddr, gas: 1500000 })
          .on('receipt', function(receipt) {
            expect(receipt.events.DivergenceFound).not.to.be.undefined;
          });
        returnValues = response.events.DivergenceFound.returnValues;
        expect(+returnValues.timeOfDivergence).to.equal(lastAggreement);
        // check if the state is DivergenceFound
        currentState = yield depthContract.methods
          .currentState().call({ from: bobAddr });
        expect(currentState).to.equal('4');
        break;
      } else {
        // send query with last queried time of aggreement
        response = yield depthContract.methods
          .makeQuery(lastConsensualQuery, leftPoint, rightPoint)
          .send({ from: aliceAddr, gas: 1500000 })
          .on('receipt', function(receipt) {
            expect(receipt.events.QueryPosted).not.to.be.undefined;
          });
      }
    }

    // kill contract
    response = yield depthContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
  });

  it('Claimer timeout', function*() {
    this.timeout(15000)

    // deploy contract and update object
    depthContract = yield depthContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, bobAddr, initialHash, bobFinalHash,
                  finalTime, querySize, roundDuration]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // check if the state is WaitingHashes
    currentState = yield depthContract.methods
      .currentState().call({ from: bobAddr });
    expect(currentState).to.equal('1');

    // mimic a waiting period of 3500 seconds
    response = yield sendRPC({jsonrpc: "2.0", method: "evm_increaseTime",
                              params: [3500], id: 0});

    // alice claiming victory should fail
    response = yield depthContract.methods
      .claimVictoryByTime()
      .send({ from: aliceAddr, gas: 1500000 })
      .catch(function(error) {
        expect(error.message).to.have.string('VM Exception');
      });

    // mimic a waiting period of 200 seconds
    response = yield sendRPC({jsonrpc: "2.0", method: "evm_increaseTime",
                              params: [200], id: 0});

    // alice claiming victory should now work
    response = yield depthContract.methods
      .claimVictoryByTime()
      .send({ from: aliceAddr, gas: 1500000 });
    returnValues = response.events.ChallengeEnded.returnValues;
    expect(+returnValues.theState).to.equal(2);

    // check if the state is ChallengerWon
    currentState = yield depthContract.methods
      .currentState().call({ from: bobAddr });
    expect(currentState).to.equal('2');

    // kill contract
    response = yield depthContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });

  });

  it('Challenger timeout', function*() {
    this.timeout(15000)

    // deploy contract and update object
    depthContract = yield depthContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, bobAddr, initialHash, bobFinalHash,
                  finalTime, querySize, roundDuration]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // check if the state is WaitingHashes
    currentState = yield depthContract.methods
      .currentState().call({ from: bobAddr });
    expect(currentState).to.equal('1');

    // create empty arrays for query and reply
    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");

    // get the query array and prepare response
    // (loop since solidity cannot return dynamic array from function)
    for (i = 0; i < querySize; i++) {
        queryArray[i] = yield depthContract.methods
            .queryArray(i).call({ from: bobAddr });
        replyArray[i] = bobHistory[queryArray[i]];
    }

    // send hashes
    response = yield depthContract.methods
        .replyQuery(queryArray, replyArray)
        .send({ from: bobAddr, gas: 1500000 })
        .on('receipt', function(receipt) {
            expect(receipt.events.HashesPosted).not.to.be.undefined;
        });
    returnValues = response.events.HashesPosted.returnValues;

    // mimic a waiting period of 3500 seconds
    response = yield sendRPC({jsonrpc: "2.0", method: "evm_increaseTime",
                              params: [3500], id: 0});

    // bob claiming victory should fail
    response = yield depthContract.methods
      .claimVictoryByTime()
      .send({ from: bobAddr, gas: 1500000 })
      .catch(function(error) {
        expect(error.message).to.have.string('VM Exception');
      });

    // mimic a waiting period of 200 seconds
    response = yield sendRPC({jsonrpc: "2.0", method: "evm_increaseTime",
                              params: [200], id: 0});

    // bob claiming victory should now work
    response = yield depthContract.methods
      .claimVictoryByTime()
      .send({ from: bobAddr, gas: 1500000 });
    returnValues = response.events.ChallengeEnded.returnValues;
    expect(+returnValues.theState).to.equal(3);

    // check if the state is ClaimerWon
    currentState = yield depthContract.methods
      .currentState().call({ from: bobAddr });
    expect(currentState).to.equal('3');

    // kill contract
    response = yield depthContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
  });
});




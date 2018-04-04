const mm = require('../utils/mm.js');
const BigNumber = require('bignumber.js');

var expect = require('chai').expect;
var getEvent = require('../utils/tools.js').getEvent;
var unwrap = require('../utils/tools.js').unwrap;
var shouldThrow = require('../utils/tools.js').shouldThrow;

var PartitionInterface = artifacts.require("./PartitionInterface.sol");

contract('PartitionInterface', function() {
  beforeEach(function() {
    //this.timeout(15000)

    // promisify jsonRPC direct call
    sendRPC = function(param){
      return new Promise(function(resolve, reject){
        web3.currentProvider.sendAsync(param, function(err, data){
          if(err !== null) return reject(err);
          resolve(data);
        });
      });
    }

    // prepare contest
    initialHash = web3.utils.sha3('start');
    aliceFinalHash = initialHash;
    bobFinalHash = initialHash;

    aliceHistory = [];
    bobHistory = [];

    finalTime = 50000;
    querySize = 3;
    roundDuration = 3600;
    lastAggreement = Math.floor((Math.random() * finalTime - 1) + 1);

    for (i = 0; i <= finalTime; i++) {
      aliceHistory.push(aliceFinalHash);
      bobHistory.push(bobFinalHash);
      aliceFinalHash = web3.utils.sha3(aliceFinalHash);
      bobFinalHash = web3.utils.sha3(bobFinalHash);
      // introduce bob mistake
      if (i == lastAggreement)
      { bobFinalHash = web3.utils.sha3('mistake'); }
    }
    // create contract object
    partitionContract = new web3.eth.Contract(abi);

    // another option is using a node serving in port 8545 with those users
    // web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
  });

  it('Find divergence', function*() {
    this.timeout(15000)

    // deploy contract and update object
    partitionContract = yield partitionContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, bobAddr, initialHash, bobFinalHash,
                  finalTime, querySize, roundDuration]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // this line should leave after they fix this bug
    // https://github.com/ethereum/web3.js/issues/1266
    partitionContract.setProvider(web3.currentProvider)

    console.log(partitionContract.options.address);

    // create empty arrays for query and reply
    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");

    while (true) {
      var i;
      // check if the state is WaitingHashes
      currentState = yield partitionContract.methods
        .currentState().call({ from: bobAddr });
      expect(currentState).to.equal('1');

      // get the query array and prepare response
      // (loop since solidity cannot return dynamic array from function)
      for (i = 0; i < querySize; i++) {
        queryArray[i] = yield partitionContract.methods
          .queryArray(i).call({ from: bobAddr });
        replyArray[i] = bobHistory[queryArray[i]];
      }
      //console.log(queryArray);

      // sending hashes from alice should fail
      response = yield partitionContract.methods
        .replyQuery(queryArray, replyArray)
        .send({ from: aliceAddr, gas: 1500000 })
        .catch(function(error) {
          expect(error.message).to.have.string('VM Exception');
        });

      // alice claiming victory should fail
      response = yield partitionContract.methods
        .claimVictoryByTime()
        .send({ from: aliceAddr, gas: 1500000 })
        .catch(function(error) {
          expect(error.message).to.have.string('VM Exception');
        });

      // send hashes
      response = yield partitionContract.methods
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
      currentState = yield partitionContract.methods
        .currentState().call({ from: bobAddr });
      expect(currentState).to.equal('0');

      // bob claiming victory should fail
      response = yield partitionContract.methods
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
        response = yield partitionContract.methods
          .presentDivergence(leftPoint)
          .send({ from: aliceAddr, gas: 1500000 })
          .on('receipt', function(receipt) {
            expect(receipt.events.DivergenceFound).not.to.be.undefined;
          });
        returnValues = response.events.DivergenceFound.returnValues;
        expect(+returnValues.timeOfDivergence).to.equal(lastAggreement);
        // check if the state is DivergenceFound
        currentState = yield partitionContract.methods
          .currentState().call({ from: bobAddr });
        expect(currentState).to.equal('4');
        break;
      } else {
        // send query with last queried time of aggreement
        response = yield partitionContract.methods
          .makeQuery(lastConsensualQuery, leftPoint, rightPoint)
          .send({ from: aliceAddr, gas: 1500000 })
          .on('receipt', function(receipt) {
            expect(receipt.events.QueryPosted).not.to.be.undefined;
          });
      }
    }

    // kill contract
    response = yield partitionContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
  });

  it('Claimer timeout', function*() {
    this.timeout(15000)

    // deploy contract and update object
    partitionContract = yield partitionContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, bobAddr, initialHash, bobFinalHash,
                  finalTime, querySize, roundDuration]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // this line should leave after they fix this bug
    // https://github.com/ethereum/web3.js/issues/1266
    partitionContract.setProvider(web3.currentProvider)

    // check if the state is WaitingHashes
    currentState = yield partitionContract.methods
      .currentState().call({ from: bobAddr });
    expect(currentState).to.equal('1');

    // mimic a waiting period of 3500 seconds
    response = yield sendRPC({jsonrpc: "2.0", method: "evm_increaseTime",
                              params: [3500], id: 0});

    // alice claiming victory should fail
    response = yield partitionContract.methods
      .claimVictoryByTime()
      .send({ from: aliceAddr, gas: 1500000 })
      .catch(function(error) {
        expect(error.message).to.have.string('VM Exception');
      });

    // mimic a waiting period of 200 seconds
    response = yield sendRPC({jsonrpc: "2.0", method: "evm_increaseTime",
                              params: [200], id: 0});

    // alice claiming victory should now work
    response = yield partitionContract.methods
      .claimVictoryByTime()
      .send({ from: aliceAddr, gas: 1500000 });
    returnValues = response.events.ChallengeEnded.returnValues;
    expect(+returnValues.theState).to.equal(2);

    // check if the state is ChallengerWon
    currentState = yield partitionContract.methods
      .currentState().call({ from: bobAddr });
    expect(currentState).to.equal('2');

    // kill contract
    response = yield partitionContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });

  });

  it('Challenger timeout', function*() {
    this.timeout(15000)

    // deploy contract and update object
    partitionContract = yield partitionContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, bobAddr, initialHash, bobFinalHash,
                  finalTime, querySize, roundDuration]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // this line should leave after they fix this bug
    // https://github.com/ethereum/web3.js/issues/1266
    partitionContract.setProvider(web3.currentProvider)

    // check if the state is WaitingHashes
    currentState = yield partitionContract.methods
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
        queryArray[i] = yield partitionContract.methods
            .queryArray(i).call({ from: bobAddr });
        replyArray[i] = bobHistory[queryArray[i]];
    }

    // send hashes
    response = yield partitionContract.methods
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
    response = yield partitionContract.methods
      .claimVictoryByTime()
      .send({ from: bobAddr, gas: 1500000 })
      .catch(function(error) {
        expect(error.message).to.have.string('VM Exception');
      });

    // mimic a waiting period of 200 seconds
    response = yield sendRPC({jsonrpc: "2.0", method: "evm_increaseTime",
                              params: [200], id: 0});

    // bob claiming victory should now work
    response = yield partitionContract.methods
      .claimVictoryByTime()
      .send({ from: bobAddr, gas: 1500000 });
    returnValues = response.events.ChallengeEnded.returnValues;
    expect(+returnValues.theState).to.equal(3);

    // check if the state is ClaimerWon
    currentState = yield partitionContract.methods
      .currentState().call({ from: bobAddr });
    expect(currentState).to.equal('3');

    // kill contract
    response = yield partitionContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
  });
});




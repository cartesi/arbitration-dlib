const mm = require('../utils/mm.js');
const BigNumber = require('bignumber.js');
const Web3 = require('web3');

//var provider = new Web3.providers.HttpProvider("http://127.0.0.1:9545/");

var web3 = new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:9545'));
//web3.setProvider(provider);
var expect = require('chai').expect;
var getEvent = require('../utils/tools.js').getEvent;
var unwrap = require('../utils/tools.js').unwrap;
var getError = require('../utils/tools.js').getError;
var sendRPC = require('../utils/tools.js').sendRPC;

var PartitionInterface = artifacts.require("./PartitionInterface.sol");

contract('PartitionInterface', function(accounts) {
  beforeEach(function() {

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
  });

  it('Find divergence', async function() {

    // deploy contract and update object
    let partitionInterface = await PartitionInterface
        .new(accounts[0], accounts[1], initialHash, bobFinalHash,
             finalTime, querySize, roundDuration,
             { from: accounts[2], gas: 2000000 });

    // create empty arrays for query and reply
    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");

    while (true) {
      var i;
      // check if the state is WaitingHashes
      currentState = await partitionInterface.currentState.call();
      expect(currentState.toNumber()).to.equal(1);

      // get the query array and prepare response
      // (loop since solidity cannot return dynamic array from function)
      for (i = 0; i < querySize; i++) {
        queryArray[i] = await partitionInterface
          .queryArray.call(i, { from: accounts[1] });
        replyArray[i] = bobHistory[queryArray[i]];
      }
      //console.log(queryArray);

      // sending hashes from alice should fail
      expect(await getError(
        partitionInterface.replyQuery(queryArray, replyArray,
                                      { from: accounts[0], gas: 1500000 }))
            ).to.have.string('VM Exception');

      // alice claiming victory should fail
      expect(await getError(
        partitionInterface
          .claimVictoryByTime({ from: accounts[0], gas: 1500000 }))
            ).to.have.string('VM Exception');

      // send hashes
      response = await partitionInterface
        .replyQuery(queryArray, replyArray,
                    { from: accounts[1], gas: 1500000 })
      event = getEvent(response, 'HashesPosted');
      expect(event).not.to.be.undefined;

      // find first last time of query where there was aggreement
      var lastConsensualQuery = 0;
      for (i = 0; i < querySize - 1; i++){
        if (aliceHistory[event.thePostedTimes[i]]
            == event.thePostedHashes[i]) {
          lastConsensualQuery = i;
        } else {
          break;
        }
      }

      // check if the state is WaitingQuery
      currentState = await partitionInterface.currentState.call();
      expect(currentState.toNumber()).to.equal(0);

      // bob claiming victory should fail
      expect(await getError(
        partitionInterface.claimVictoryByTime(
          { from: accounts[1], gas: 1500000 }))
            ).to.have.string('VM Exception');

      leftPoint = event.thePostedTimes[lastConsensualQuery];
      rightPoint = event.thePostedTimes[lastConsensualQuery + 1];
      // check if the interval is unitary
      if (+rightPoint == +leftPoint + 1) {
        // if the interval is unitary, present divergence
        response = await partitionInterface.presentDivergence(
          leftPoint.toString(), { from: accounts[0], gas: 1500000 })
        event = getEvent(response, 'DivergenceFound');
        expect(event).not.to.be.undefined;
        expect(+event.timeOfDivergence).to.equal(lastAggreement);
        // check if the state is DivergenceFound
        currentState = await partitionInterface.currentState.call();
        expect(currentState.toNumber()).to.equal(4);
        break;
      } else {
        // send query with last queried time of aggreement
        response = await partitionInterface
          .makeQuery(lastConsensualQuery, leftPoint.toString(),
                     rightPoint.toString(), { from: accounts[0], gas: 1500000 })
        expect(getEvent(response, 'QueryPosted')).not.to.be.undefined;
      }
    }

    // kill contract
    response = await partitionInterface
      .kill({ from: accounts[2], gas: 1500000 });
    // check if contract was killed
    [error, currentState] = await unwrap(partitionInterface.currentState());
    expect(error.message).to.have.string('not a contract address');;
  });

  it('Claimer timeout', async function() {

    // deploy contract and update object
    let partitionInterface = await PartitionInterface
        .new(accounts[0], accounts[1], initialHash, bobFinalHash,
             finalTime, querySize, roundDuration,
             { from: accounts[2], gas: 2000000 });

    // check if the state is WaitingHashes
    currentState = await partitionInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(1);

    // mimic a waiting period of 3500 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [3500], id: 0});

    // alice claiming victory should fail
    expect(await getError(
      partitionInterface.claimVictoryByTime(
        { from: accounts[0], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // mimic a waiting period of 200 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [200], id: 0});

    // alice claiming victory should now work
    response = await partitionInterface
      .claimVictoryByTime({ from: accounts[0], gas: 1500000 });
    event = getEvent(response, 'ChallengeEnded');
    expect(+event.theState).to.equal(2);

    // check if the state is ChallengerWon
    currentState = await partitionInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(2);

    // kill contract
    response = await partitionInterface
      .kill({ from: accounts[2], gas: 1500000 });

    // check if contract was killed
    [error, currentState] = await unwrap(partitionInterface.currentState());
    expect(error.message).to.have.string('not a contract address');;
  });

  it('Challenger timeout', async function() {
    // deploy contract and update object
    let partitionInterface = await PartitionInterface
        .new(accounts[0], accounts[1], initialHash, bobFinalHash,
             finalTime, querySize, roundDuration,
             { from: accounts[2], gas: 2000000 });

    // check if the state is WaitingHashes
    currentState = await partitionInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(1);

    // create empty arrays for query and reply
    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");

    // get the query array and prepare response
    // (loop since solidity cannot return dynamic array from function)
    for (i = 0; i < querySize; i++) {
      queryArray[i] = await partitionInterface
        .queryArray(i, { from: accounts[1] });
      replyArray[i] = bobHistory[queryArray[i]];
    }

    // send hashes
    response = await partitionInterface
      .replyQuery(queryArray, replyArray,
                  { from: accounts[1], gas: 1500000 })

    expect(getEvent(response, 'HashesPosted')).not.to.be.undefined;

    // mimic a waiting period of 3500 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [3500], id: 0});

    // bob claiming victory should fail
    expect(await getError(
      partitionInterface
        .claimVictoryByTime({ from: accounts[1], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // mimic a waiting period of 200 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [200], id: 0});

    // bob claiming victory should now work
    response = await partitionInterface
      .claimVictoryByTime({ from: accounts[1], gas: 1500000 });
    event = getEvent(response, 'ChallengeEnded');
    expect(+event.theState).to.equal(3);

    // check if the state is ClaimerWon
    currentState = await partitionInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(3);

    // kill contract
    response = await partitionInterface
      .kill({ from: accounts[2], gas: 1500000 });

    // check if contract was killed
    [error, currentState] = await unwrap(partitionInterface.currentState());
    expect(error.message).to.have.string('not a contract address');;

  });
});

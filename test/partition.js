const BigNumber = require('bignumber.js');
const Web3 = require('web3');

const mm = require('../utils/mm.js');
const expect = require('chai').expect;
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;
const sendRPC = require('../utils/tools.js').sendRPC;

var web3 = new Web3('http://127.0.0.1:9545');

var PartitionInstantiator = artifacts.require("./PartitionInstantiator.sol");

contract('PartitionInstantiator', function(accounts) {
  let index;

  before(function() {

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
    let partitionInstantiator = await PartitionInstantiator.new();
    // instantiate a partition
    response = await partitionInstantiator.instantiate(
      accounts[0], accounts[1], initialHash, bobFinalHash,
      finalTime, querySize, roundDuration,
      { from: accounts[9], gas: 2000000 });
    event = getEvent(response, 'PartitionCreated');
    index = event._index.toNumber();

    // create empty arrays for query and reply
    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");

    while (true) {
      var i;
      // check if the state is WaitingHashes
      currentState = await partitionInstantiator.currentState.call(index);
      expect(currentState.toNumber()).to.equal(1);

      // get the query array and prepare response
      // (loop since solidity cannot return dynamic array from function)
      for (i = 0; i < querySize; i++) {
        queryArray[i] = await partitionInstantiator
          .queryArray.call(index, i, { from: accounts[1] });
        replyArray[i] = bobHistory[queryArray[i]];
      }

      // sending hashes from alice should fail
      expect(await getError(
        partitionInstantiator.replyQuery(index, queryArray, replyArray,
                                         { from: accounts[0], gas: 1500000 }))
            ).to.have.string('VM Exception');

      // alice claiming victory should fail
      expect(await getError(
        partitionInstantiator
          .claimVictoryByTime(index, { from: accounts[0], gas: 1500000 }))
            ).to.have.string('VM Exception');

      // send hashes
      response = await partitionInstantiator
        .replyQuery(index, queryArray, replyArray,
                    { from: accounts[1], gas: 1500000 })
      event = getEvent(response, 'HashesPosted');
      expect(event).not.to.be.undefined;

      // find first last time of query where there was aggreement
      var lastConsensualQuery = 0;
      for (i = 0; i < querySize - 1; i++){
        if (aliceHistory[event._postedTimes[i]]
            == event._postedHashes[i]) {
          lastConsensualQuery = i;
        } else {
          break;
        }
      }

      // check if the state is WaitingQuery
      currentState = await partitionInstantiator.currentState.call(index);
      expect(currentState.toNumber()).to.equal(0);

      // bob claiming victory should fail
      expect(await getError(
        partitionInstantiator.claimVictoryByTime(
          index,
          { from: accounts[1], gas: 1500000 }))
            ).to.have.string('VM Exception');

      leftPoint = event._postedTimes[lastConsensualQuery];
      rightPoint = event._postedTimes[lastConsensualQuery + 1];
      // check if the interval is unitary
      if (+rightPoint == +leftPoint + 1) {
        // if the interval is unitary, present divergence
        response = await partitionInstantiator.presentDivergence(
          index, leftPoint.toString(), { from: accounts[0], gas: 1500000 })
        event = getEvent(response, 'DivergenceFound');
        expect(event).not.to.be.undefined;
        expect(+event._timeOfDivergence).to.equal(lastAggreement);
        // check if the state is DivergenceFound
        currentState = await partitionInstantiator.currentState.call(index);
        expect(currentState.toNumber()).to.equal(4);
        break;
      } else {
        // send query with last queried time of aggreement
        response = await partitionInstantiator
          .makeQuery(index, lastConsensualQuery, leftPoint.toString(),
                     rightPoint.toString(), { from: accounts[0], gas: 1500000 })
        expect(getEvent(response, 'QueryPosted')).not.to.be.undefined;
      }
    }
  });

  it('Claimer timeout', async function() {
    // deploy contract and update object
    let partitionInstantiator = await PartitionInstantiator.new();
    // instantiate a partition
    response = await partitionInstantiator.instantiate(
      accounts[2], accounts[3], initialHash, bobFinalHash,
      finalTime, querySize, roundDuration,
      { from: accounts[9], gas: 2000000 });
    event = getEvent(response, 'PartitionCreated');
    index = event._index.toNumber();

    // check if the state is WaitingHashes
    currentState = await partitionInstantiator.currentState.call(index);
    expect(currentState.toNumber()).to.equal(1);

    // mimic a waiting period of 3500 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [3500], id: 0});

    // alice claiming victory should fail
    expect(await getError(
      partitionInstantiator.claimVictoryByTime(
        index,
        { from: accounts[2], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // mimic a waiting period of 200 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [200], id: 0});

    // alice claiming victory should now work
    response = await partitionInstantiator
      .claimVictoryByTime(index, { from: accounts[2], gas: 1500000 });
    event = getEvent(response, 'ChallengeEnded');
    expect(+event._state).to.equal(2);

    // check if the state is ChallengerWon
    currentState = await partitionInstantiator.currentState.call(index);
    expect(currentState.toNumber()).to.equal(2);
  });

  it('Challenger timeout', async function() {
    // deploy contract and update object
    let partitionInstantiator = await PartitionInstantiator.new();
    // instantiate a partition
    response = await partitionInstantiator.instantiate(
      accounts[4], accounts[5], initialHash, bobFinalHash,
      finalTime, querySize, roundDuration,
      { from: accounts[9], gas: 2000000 });
    event = getEvent(response, 'PartitionCreated');
    index = event._index.toNumber();

    // check if the state is WaitingHashes
    currentState = await partitionInstantiator.currentState.call(index);
    expect(currentState.toNumber()).to.equal(1);

    // create empty arrays for query and reply
    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");

    // get the query array and prepare response
    // (loop since solidity cannot return dynamic array from function)
    for (i = 0; i < querySize; i++) {
      queryArray[i] = await partitionInstantiator
        .queryArray(index, i, { from: accounts[5] });
      replyArray[i] = bobHistory[queryArray[i]];
    }

    // send hashes
    response = await partitionInstantiator
      .replyQuery(index, queryArray, replyArray,
                  { from: accounts[5], gas: 1500000 })

    expect(getEvent(response, 'HashesPosted')).not.to.be.undefined;

    // mimic a waiting period of 3500 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [3500], id: 0});

    // bob claiming victory should fail
    expect(await getError(
      partitionInstantiator
        .claimVictoryByTime(index, { from: accounts[5], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // mimic a waiting period of 200 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [200], id: 0});

    // bob claiming victory should now work
    response = await partitionInstantiator
      .claimVictoryByTime(index, { from: accounts[5], gas: 1500000 });
    event = getEvent(response, 'ChallengeEnded');
    expect(+event._state).to.equal(3);

    // check if the state is ClaimerWon
    currentState = await partitionInstantiator.currentState.call(index);
    expect(currentState.toNumber()).to.equal(3);
  });
});

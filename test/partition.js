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
  let partitionInstantiator;
  let queryArray;
  let replyArray;
  let randomFunctions;
  let cannotAct;

  beforeEach(async function() {
    // prepare contest
    initialHash = web3.utils.sha3('start');
    challengerFinalHash = initialHash;
    claimerFinalHash = initialHash;
    challengerHistory = [];
    claimerHistory = [];
    finalTime = 50000;
    querySize = 3;
    roundDuration = '3600';
    lastAggreement = Math.floor((Math.random() * finalTime - 1) + 1);
    for (i = 0; i <= finalTime; i++) {
      challengerHistory.push(challengerFinalHash);
      claimerHistory.push(claimerFinalHash);
      challengerFinalHash = web3.utils.sha3(challengerFinalHash);
      claimerFinalHash = web3.utils.sha3(claimerFinalHash);
      // introduce claimer's mistake
      if (i == lastAggreement)
      { claimerFinalHash = web3.utils.sha3('introducing mistake'); }
    }
    // create empty arrays for query and reply
    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");
    partitionInstantiator = await PartitionInstantiator.new();
    // instantiate a partition
    response = await partitionInstantiator.instantiate(
      accounts[0], accounts[1], initialHash, claimerFinalHash,
      finalTime, querySize, roundDuration,
      { from: accounts[9], gas: 2000000 });
    event = getEvent(response, 'PartitionCreated');
    index = event._index.toNumber();
    // check if the state is WaitingHashes
    expect(await partitionInstantiator.stateIsWaitingHashes.call(index))
      .to.be.true;
    // create random functions to serve as levers
    // but first, some sensible arguments
    for (i = 0; i < querySize; i++) {
      queryArray[i] = await partitionInstantiator
        .queryArray(index, i, { from: accounts[1] });
      replyArray[i] = claimerHistory[queryArray[i]];
    }
    randomFunctions = [
      { name: 'replyQuery', args: [ index, queryArray, replyArray ] },
      { name: 'makeQuery', args: [ index, 0, queryArray[0], queryArray[1] ] },
      { name: 'claimVictoryByTime', args: [ index ] },
      { name: 'presentDivergence', args: [ index, 0 ] }
    ];
    cannotAct = async function(address) {
      for (let i = 0; i < randomFunctions.length; i++) {
        let args = randomFunctions[i].args;
        args.push({ from: address, gas: 1500000 });
        expect(await getError(
          partitionInstantiator[randomFunctions[i].name].apply(null, args))
              ).to.have.string('VM Exception');
      }
    };
    // challenger cannot act in this turn
    await cannotAct(accounts[0]);
  });

  describe('Claimer timeout', async function() {
    it('Contract should reach ChallengerWon state', async function() {
      // mimic a waiting period of 3500 seconds
      response = await sendRPC(web3, { jsonrpc: "2.0",
                                       method: "evm_increaseTime",
                                       params: [3500], id: Date.now() });
      // challenger claiming victory should fail
      expect(await getError(
        partitionInstantiator.claimVictoryByTime(
          index,
          { from: accounts[2], gas: 1500000 }))
            ).to.have.string('VM Exception');
      // mimic a waiting period of 200 seconds
      response = await sendRPC(web3, { jsonrpc: "2.0",
                                      method: "evm_increaseTime",
                                      params: [200], id: Date.now() });
      // challenger claiming victory should now work
      response = await partitionInstantiator
        .claimVictoryByTime(index, { from: accounts[0], gas: 1500000 });
      event = getEvent(response, 'ChallengeEnded');
      expect(+event._state).to.equal(2);
      // check if the state is ChallengerWon
      expect(await partitionInstantiator.stateIsChallengerWon.call(index))
        .to.be.true;
      // no one can act now
      await cannotAct(accounts[0]);
      await cannotAct(accounts[1]);
    });
  });

  describe('Challenger timeout', async function() {
    it('Contract should reach ClaimerWon state', async function() {
      // (loop since solidity cannot return dynamic array from function)
      for (i = 0; i < querySize; i++) {
        queryArray[i] = await partitionInstantiator
          .queryArray(index, i, { from: accounts[1] });
        replyArray[i] = claimerHistory[queryArray[i]];
      }
      // send hashes
      response = await partitionInstantiator
        .replyQuery(index, queryArray, replyArray,
                    { from: accounts[1], gas: 1500000 })
      expect(getEvent(response, 'HashesPosted')).not.to.be.undefined;
      // claimer cannot act now
      await cannotAct(accounts[1]);
      // mimic a waiting period of 3500 seconds
      response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                      params: [3500], id: Date.now()});
      // claimer claiming victory should fail
      expect(await getError(
        partitionInstantiator
          .claimVictoryByTime(index, { from: accounts[1], gas: 1500000 }))
            ).to.have.string('VM Exception');
      // mimic a waiting period of 200 seconds
      response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                      params: [200], id: Date.now()});
      // claimer claiming victory should now work
      response = await partitionInstantiator
        .claimVictoryByTime(index, { from: accounts[1], gas: 1500000 });
      event = getEvent(response, 'ChallengeEnded');
      expect(+event._state).to.equal(3);
      // check if the state is ClaimerWon
      expect(await partitionInstantiator.stateIsClaimerWon.call(index))
        .to.be.true;
      // no one can act now
      await cannotAct(accounts[0]);
      await cannotAct(accounts[1]);
    });
  });

  describe('Divergence found', async function() {
    it('Contract should reach DivergenceFound state', async function() {
      while (true) {
        var i;
        // check if the state is WaitingHashes
        expect(await partitionInstantiator.stateIsWaitingHashes.call(index))
          .to.be.true;
        // challenger cannot act now
        await cannotAct(accounts[0]);
        // get the query array and prepare response
        // (loop since solidity cannot return dynamic array from function)
        for (i = 0; i < querySize; i++) {
          queryArray[i] = await partitionInstantiator
            .queryArray.call(index, i, { from: accounts[1] });
          replyArray[i] = claimerHistory[queryArray[i]];
        }
        // challenger claiming victory should fail
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
        // claimer cannot act now
        await cannotAct(accounts[1])
        // find first last time of query where there was aggreement
        var lastConsensualQuery = 0;
        for (i = 0; i < querySize - 1; i++){
          if (challengerHistory[event._postedTimes[i]]
              == event._postedHashes[i]) {
            lastConsensualQuery = i;
          } else {
            break;
          }
        }
        // check if the state is WaitingQuery
        expect(await partitionInstantiator.stateIsWaitingQuery.call(index))
          .to.be.true;
        // claimer cannot act now
        await cannotAct(accounts[1])
        // claimer claiming victory should fail
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
          expect(await partitionInstantiator.stateIsDivergenceFound.call(index))
            .to.be.true;
          // no one can act now
          await cannotAct(accounts[0]);
          await cannotAct(accounts[1]);
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
  });
});

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

  it('Instantiate should work with different slice path', async function(){
    response = await partitionInstantiator.instantiate(
      accounts[0], accounts[1], initialHash, claimerFinalHash,
      1, querySize, roundDuration,
      { from: accounts[9], gas: 2000000 });
    event2 = getEvent(response, 'PartitionCreated');
    index2 = event2._index.toNumber();
    // check if the state is WaitingHashes
    expect(await partitionInstantiator.stateIsWaitingHashes.call(index2))
      .to.be.true;

  });
  describe('Instantiate Requires should throw exception', async function() {
    it('Challenger and Claimer cant have the same address', async function (){
      expect(await getError(partitionInstantiator.instantiate(accounts[0], accounts[0], initialHash, claimerFinalHash,finalTime, querySize, roundDuration,{ from: accounts[9], gas: 2000000 }))
      ).to.have.string('VM Exception');
    });

    it('Final time has to be bigger than zero', async function (){
      expect(await getError(partitionInstantiator.instantiate(accounts[0], accounts[1], initialHash, claimerFinalHash,
        0, querySize, roundDuration, { from: accounts[9], gas: 2000000 }))
      ).to.have.string('VM Exception');
    });

    it('Query Size must be bigger than 2', async function (){
      expect(await getError(partitionInstantiator.instantiate(accounts[0], accounts[1], initialHash, claimerFinalHash,
        finalTime, 2, roundDuration, { from: accounts[9], gas: 2000000 }))
      ).to.have.string('VM Exception');
    });

    it('Query Size must be less than 100', async function (){
      expect(await getError(partitionInstantiator.instantiate(accounts[0], accounts[1], initialHash, claimerFinalHash,
        finalTime, 100, roundDuration, { from: accounts[9], gas: 2000000 }))
      ).to.have.string('VM Exception');
    });
  });
  // Replyquery requires should fail when: 
  describe('Calling replyQuery ', async function() {
    it('Posted times.length should equal querysize', async function() {
      expect(await getError(partitionInstantiator
        .replyQuery(index,[1] , replyArray,
          { from: accounts[1], gas: 1500000 })
      )).to.have.string('VM Exception');
    });
    
    it('Posted hashes.length should equal to querysize', async function() {
      expect(await getError(partitionInstantiator
        .replyQuery(index,queryArray , ['incorrect'],
          { from: accounts[1], gas: 1500000 })
      )).to.have.string('VM Exception');
    });
    it('Posted times elements should equal to querysize elements', async function() {
      expect(await getError(partitionInstantiator
        .replyQuery(index, [1,2,3] , replyArray,
          { from: accounts[1], gas: 1500000 })
      )).to.have.string('VM Exception');
    });



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
               
          // present divergence should fail if divergence time > final time
          expect(await getError(partitionInstantiator
            .presentDivergence(
            index, 50001, { from: accounts[0], gas: 1500000 })
          )).to.have.string('VM Exception');

          // present divergence should fail if divergence time has not been submited
          expect(await getError(partitionInstantiator
            .presentDivergence(
            index, 50000, { from: accounts[0], gas: 1500000 })
          )).to.have.string('VM Exception');

          response = await partitionInstantiator.presentDivergence(
            index, leftPoint.toString(), { from: accounts[0], gas: 1500000 })
          event = getEvent(response, 'DivergenceFound');
          expect(event).not.to.be.undefined;
          expect(+event._timeOfDivergence).to.equal(lastAggreement);
       
          // check if the state is divergencefound
          expect(await partitionInstantiator.stateIsDivergenceFound.call(index))
            .to.be.true;

          // check if divergencetime == leftpoint
          response = await partitionInstantiator.divergenceTime(index);
          expect(response).to.equal(leftPoint);

          // check if time submitted[divergencetime == true] 
          response = await partitionInstantiator.timeSubmitted(index, leftPoint);
          expect(response).to.true;
          
          // check if timehash of divergence time is not undefined
          response = await partitionInstantiator.timeHash(index, leftPoint);
          expect(response).to.be.defined;
      
          // no one can act now
          await cannotAct(accounts[0]);
          await cannotAct(accounts[1]);
          break;
        } else {

          //make query should fail when queryPiece > querysize - 1:
          expect(await getError(partitionInstantiator
            .makeQuery(index, 5, leftPoint.toString(),rightPoint.toString(),
            { from: accounts[0], gas: 1500000 })
          )).to.have.string('VM Exception');

          //make query should fail when leftpoint != queryPiece
          expect(await getError(partitionInstantiator
            .makeQuery(index, lastConsensualQuery, (leftPoint-1).toString(),rightPoint.toString(),
            { from: accounts[0], gas: 1500000 })
          )).to.have.string('VM Exception');

          //make query should fail when leftpoint != queryPiece
          expect(await getError(partitionInstantiator
            .makeQuery(index, lastConsensualQuery, leftPoint.toString(),(rightPoint+1).toString(),
            { from: accounts[0], gas: 1500000 })
          )).to.have.string('VM Exception');


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

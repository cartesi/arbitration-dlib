const BigNumber = require('bignumber.js');
const Web3 = require('web3');

const mm = require('../utils/mm.js');
const subleq = require('../utils/subleq.js')

const expect = require('chai').expect;
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;
const sendRPC = require('../utils/tools.js').sendRPC;
const twoComplement32 = require('../utils/tools.js').twoComplement32;

var web3 = new Web3('http://127.0.0.1:9545');

var MMInstantiator = artifacts.require("./MMInstantiator.sol");
var PartitionInstantiator = artifacts.require("./PartitionInstantiator.sol");
var Token = artifacts.require("./lib/bokkypoobah/Token.sol");
var VGInstantiator = artifacts.require("./VGInstantiator.sol");

contract('VGInstantiator', function(accounts) {
  let index;
  let initialHash;
  let initMachine;
  let aliceSubleq;
  let bobSubleq;
  let aliceMM;
  let bobMM;
  let claimerFinalHash;
  let finalTime;

  before(function() {
    let echo_binary = [-1, 21, 3,
                       21, -1, 6,
                       21, 22, 9,
                       22, 23, -1,
                       21, 21, 15,
                       22, 22, 18,
                       23, 23, 0,
                       0, 0, 0]

    let input_string = [2, 4, 8, 16, 32, 64, -1];

    let hd_position = BigNumber("0x0000000000000000");
    let pc_position = BigNumber("0x4000000000000000");
    let ic_position = BigNumber("0x4000000000000008");
    let oc_position = BigNumber("0x4000000000000010");
    let halted_state = BigNumber("0x4000000000000018");
    let initial_ic = BigNumber("0x8000000000000000");
    let initial_oc = BigNumber("0xc000000000000000");
    aliceMM = new mm.MemoryManager();
    bobMM = new mm.MemoryManager();
    aliceSubleq = new subleq.Subleq(aliceMM)
    bobSubleq = new subleq.Subleq(bobMM);;

    initMachine = function(mm) {
      // write program to memory contract
      var softwareLength = echo_binary.length;
      for (let i = 0; i < softwareLength; i++) {
        mm.setValue(8 * i, twoComplement32(echo_binary[i]));
      }
      // write ic position
      mm.setValue(ic_position, initial_ic);
      expect(mm.getWord(ic_position)).to.equal(initial_ic);
      // write oc position
      mm.setValue(oc_position, initial_oc);
      // write input in memory contract
      var inputLength = input_string.length;
      for (let i = 0; i < inputLength; i++) {
        mm.setValue(initial_ic.plus(8 * i),
                    twoComplement32(input_string[i]));
        expect(mm.getWord(BigNumber(initial_ic).plus(8 * i)))
          .to.equal(twoComplement32(input_string[i]));
      }
    }

    initMachine(aliceMM);
    initMachine(bobMM);
    initialHash = aliceMM.merkel();

    finalTime = 300
    aliceSubleq.run(finalTime);
    bobSubleq.run(5);
    bobMM.setValue(ic_position, initial_ic);
    bobSubleq.run(finalTime - 5);

    claimerFinalHash = bobMM.merkel();
  });

  it.only('Find divergence', async function() {
    // deploy contract and update object
    let mmInstantiator = await MMInstantiator.new();
    let partitionInstantiator = await PartitionInstantiator.new();
    let token = await Token.new();
    aliceBalanceTokens = await token.balanceOf(accounts[0]);
    console.log(aliceBalanceTokens);
    expect(aliceBalanceTokens.toString()).to.equal('1e+27');
    let vgInstantiator = await VGInstantiator.new(
      token.address,
      partitionInstantiator.address,
      mmInstantiator.address
    );
    response = await token.approve(
      vgInstantiator.address, 1000,
      { from: accounts[0], gas: 2000000 });
    event = getEvent(response, 'Approval');
    expect(event).not.to.be.undefined;
    // instantiate a partition
    response = await vgInstantiator.instantiate(
      accounts[0], accounts[1], web3.utils.toWei('1', 'ether'),
      1000, 3600, initialHash, claimerFinalHash, finalTime,
      { from: accounts[0], gas: 2000000,
        value: web3.utils.toWei('1', 'ether') });
    event = getEvent(response, 'VGCreated');
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

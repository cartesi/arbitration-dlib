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
var Subleq = artifacts.require("./Subleq.sol");
var VGInstantiator = artifacts.require("./VGInstantiator.sol");

contract('VGInstantiator', function(accounts) {
  let vgIndex;
  let partitionIndex;
  let initialHash;
  let initMachine;
  let aliceSubleq;
  let bobSubleq;
  let aliceMM;
  let bobMM;
  let aliceHistory;
  let bobHistory;
  let claimerFinalHash;
  let finalTime;
  let querySize = 10;
  let lastAggreement = 5;

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
    let hd_position = "0x0000000000000000";
    let pc_position = "0x4000000000000000";
    let ic_position = "0x4000000000000008";
    let oc_position = "0x4000000000000010";
    let halted_state = "0x4000000000000018";
    let ram_size_position = "0x4000000000000020";
    let input_size_position = "0x4000000000000028";
    let output_size_position = "0x4000000000000030";
    let initial_ic = "0x8000000000000000";
    let initial_oc = "0xc000000000000000";
    aliceMM = new mm.MemoryManager();
    bobMM = new mm.MemoryManager();
    aliceSubleq = new subleq.Subleq(aliceMM)
    bobSubleq = new subleq.Subleq(bobMM);;

    initMachine = function(mm) {
      // write program to memory contract
      var softwareLength = echo_binary.length;
      for (let i = 0; i < softwareLength; i++) {
        mm.setWord(8 * i, twoComplement32(echo_binary[i]));
      }
      // write ic position
      mm.setWord(ic_position, initial_ic);
      expect(mm.getWord(ic_position)).to.equal(initial_ic);
      // write oc position
      mm.setWord(oc_position, initial_oc);
      // write sizes
      mm.setWord(ram_size_position, "0x0000000000010000");
      mm.setWord(input_size_position, "0x0000000000010000");
      mm.setWord(output_size_position, "0x0000000000010000");
      // write input in memory contract
      var inputLength = input_string.length;
      for (let i = 0; i < inputLength; i++) {
        mm.setWord(BigNumber(initial_ic).plus(8 * i),
                    twoComplement32(input_string[i]));
        expect(mm.getWord(BigNumber(initial_ic).plus(8 * i)))
          .to.equal(twoComplement32(input_string[i]));
      }
    }
    initMachine(aliceMM);
    initMachine(bobMM);
    initialHash = aliceMM.merkel();
    finalTime = 60;

    aliceHistory = [];
    bobHistory = [];
    for (let i = 0; i < finalTime; i++) {
      aliceHistory.push(aliceMM.merkel());
      bobHistory.push(bobMM.merkel());
      aliceSubleq.step();
      bobSubleq.step();
      if (i == lastAggreement) { bobMM.setWord(ic_position, initial_ic); }
    }
    claimerFinalHash = bobMM.merkel();
  });

  it('Find divergence', async function() {
    // deploy contract and update object
    let mmInstantiator = await MMInstantiator.new();
    let partitionInstantiator = await PartitionInstantiator.new();
    let token = await Token.new({ from: accounts[2] });
    let subleqContract = await Subleq.new({ from: accounts[2], gas: 3000000 });
    let vgInstantiator = await VGInstantiator.new(
      token.address,
      partitionInstantiator.address,
      mmInstantiator.address,
      { from: accounts[2], gas: 5000000 }
    );
    response = await token.approve(
      vgInstantiator.address, 1000,
      { from: accounts[2], gas: 2000000 });
    event = getEvent(response, 'Approval');
    expect(event).not.to.be.undefined;
    // instantiate a verification game
    response = await vgInstantiator.instantiate(
      accounts[0], accounts[1], 1000, 20000, 3600, subleqContract.address,
      initialHash, claimerFinalHash, finalTime,
      { from: accounts[2], gas: 2000000 });
    event = getEvent(response, 'VGCreated');
    vgIndex = event._index.toNumber();
    // check if the state is WaitSale
    currentState = await vgInstantiator
      .currentState.call(vgIndex);
    expect(currentState.toNumber()).to.equal(0);
    // alice attempting to win by partition timeout should fail
    expect(await getError(
      vgInstantiator
        .winByPartitionTimeout(vgIndex, { from: accounts[0], gas: 1500000 }))
          ).to.have.string('VM Exception');
    // alice attempting to start machine to run should fail
    expect(await getError(
      vgInstantiator
        .startMachineRunChallenge(vgIndex, { from: accounts[0], gas: 1500000 }))
          ).to.have.string('VM Exception');
    // mimic a waiting period equivalent to the sale phase
    response = await sendRPC(web3, { jsonrpc: "2.0",
                                     method: "evm_increaseTime",
                                     params: [20000], id: Date.now() });
    // finish sale phase
    response = await vgInstantiator.finishSalePhase(vgIndex);
    event = getEvent(response, 'StartChallenge');
    partitionIndex = event._partitionInstance.toNumber();
    // create empty arrays for query and reply
    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");
    // start the iteration in the partition search
    while (true) {
      var i;
      // check if the state is WaitingHashes
      currentState = await partitionInstantiator
        .currentState.call(partitionIndex);
      expect(currentState.toNumber()).to.equal(1);
      // get the query array and prepare response
      // (loop since solidity cannot return dynamic array from function)
      for (i = 0; i < querySize; i++) {
        queryArray[i] = await partitionInstantiator
          .queryArray.call(partitionIndex, i, { from: accounts[1] });
        replyArray[i] = bobHistory[queryArray[i]];
      }
      // sending hashes from alice should fail
      expect(await getError(
        partitionInstantiator.replyQuery(partitionIndex, queryArray, replyArray,
                                         { from: accounts[0], gas: 1500000 }))
            ).to.have.string('VM Exception');
      // alice claiming victory should fail
      expect(await getError(
        partitionInstantiator
          .claimVictoryByTime(partitionIndex,
                              { from: accounts[0], gas: 1500000 }))
            ).to.have.string('VM Exception');
      // send hashes
      response = await partitionInstantiator
        .replyQuery(partitionIndex, queryArray, replyArray,
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
      currentState = await partitionInstantiator
        .currentState.call(partitionIndex);
      expect(currentState.toNumber()).to.equal(0);
      // bob claiming victory should fail
      expect(await getError(
        partitionInstantiator.claimVictoryByTime(
          partitionIndex,
          { from: accounts[1], gas: 1500000 }))
            ).to.have.string('VM Exception');
      leftPoint = event._postedTimes[lastConsensualQuery];
      rightPoint = event._postedTimes[lastConsensualQuery + 1];
      // check if the interval is unitary
      if (+rightPoint == +leftPoint + 1) {
        // if the interval is unitary, present divergence
        response = await partitionInstantiator.presentDivergence(
          partitionIndex, leftPoint.toString(),
          { from: accounts[0], gas: 1500000 })
        event = getEvent(response, 'DivergenceFound');
        expect(event).not.to.be.undefined;
        expect(+event._timeOfDivergence).to.equal(lastAggreement);
        // check if the state is DivergenceFound
        currentState = await partitionInstantiator
          .currentState.call(partitionIndex);
        expect(currentState.toNumber()).to.equal(4);
        break;
      } else {
        // send query with last queried time of aggreement
        response = await partitionInstantiator
          .makeQuery(partitionIndex, lastConsensualQuery, leftPoint.toString(),
                     rightPoint.toString(), { from: accounts[0], gas: 1500000 })
        expect(getEvent(response, 'QueryPosted')).not.to.be.undefined;
      }
    }
    response = await vgInstantiator
      .startMachineRunChallenge(vgIndex, { from: accounts[0], gas: 1500000 });
    event = getEvent(response, 'PartitionDivergenceFound');
    expect(event).not.to.be.undefined;
    mmIndex = event._mmInstance.toNumber();
    // having found the point of divergence we simulate the machine at point
    let freshMM = new mm.MemoryManager();
    initMachine(freshMM);
    let freshSubleq = new subleq.Subleq(freshMM)
    freshSubleq.run(lastAggreement);
    // take a snapshot right before dispute
    freshMM.snapshot();
    freshMM.startRecording();
    freshSubleq.step();
    let recorded = freshMM.getRecorded();
    let finalHash = freshMM.merkel();
    freshMM.restore();
    for (let i = 0; i < recorded.length; i++)
    {
      proof = freshMM.generateProof(recorded[i][1]);
      if (recorded[i][0]) {
        response = await mmInstantiator
          .proveRead(mmIndex, recorded[i][1].toString(),
                     recorded[i][2], proof,
                     { from: accounts[0], gas: 2000000 });
      } else {
        response = await mmInstantiator
          .proveWrite(mmIndex, recorded[i][1].toString(),
                      freshMM.getWord(recorded[i][1]).toString(),
                      recorded[i][2], proof,
                      { from: accounts[0], gas: 2000000 });
        freshMM.setWord(recorded[i][1], recorded[i][2]);
      }
    }
    // check final hash
    remoteFinalHash = await mmInstantiator.newHash.call(mmIndex);
    expect(remoteFinalHash).to.equal(finalHash);
    // check if memory is still waiting proofs
    currentState = await mmInstantiator.currentState.call(mmIndex);
    expect(currentState.toNumber()).to.equal(0);
    // check that alice has no tokens
    response = await token.balanceOf(accounts[0]);
    expect(response.toNumber()).to.equal(0);
    let aliceInitialBalance = await web3.eth.getBalance(accounts[0]);
    // finish proof phase for memory manager
    response = await mmInstantiator.finishProofPhase(mmIndex);
    event = getEvent(response, 'FinishedProofs');
    expect(event).not.to.be.undefined;
    // check if memory is still waiting proofs
    currentState = await mmInstantiator.currentState.call(mmIndex);
    expect(currentState.toNumber()).to.equal(1);
    // finish challange
    response = await vgInstantiator.settleVerificationGame(
      vgIndex, { from: accounts[0], gas: 3000000 });
    event = getEvent(response, "VGFinished");
    expect(event._finalState.toNumber()).to.equal(4);
    // check that alice has a tokens
    response = await token.balanceOf(accounts[0]);
    expect(response.toNumber()).to.equal(1000);
  });
/*
  it('Claimer timeout', async function() {
    // deploy contract and update object
    let partitionInstantiator = await PartitionInstantiator.new();
    // instantiate a partition
    response = await partitionInstantiator.instantiate(
      accounts[2], accounts[3], initialHash, bobFinalHash,
      finalTime, querySize, roundDuration,
      { from: accounts[9], gas: 2000000 });
    event = getEvent(response, 'PartitionCreated');
    partitionIndex = event._index.toNumber();

    // check if the state is WaitingHashes
    currentState = await partitionInstantiator.currentState.call(partitionIndex);
    expect(currentState.toNumber()).to.equal(1);

    // mimic a waiting period of 3500 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [3500], id: 0});

    // alice claiming victory should fail
    expect(await getError(
      partitionInstantiator.claimVictoryByTime(
        partitionIndex,
        { from: accounts[2], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // mimic a waiting period of 200 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [200], id: 0});

    // alice claiming victory should now work
    response = await partitionInstantiator
      .claimVictoryByTime(partitionIndex, { from: accounts[2], gas: 1500000 });
    event = getEvent(response, 'ChallengeEnded');
    expect(+event._state).to.equal(2);

    // check if the state is ChallengerWon
    currentState = await partitionInstantiator.currentState.call(partitionIndex);
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
    partitionIndex = event._index.toNumber();

    // check if the state is WaitingHashes
    currentState = await partitionInstantiator.currentState.call(partitionIndex);
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
        .queryArray(partitionIndex, i, { from: accounts[5] });
      replyArray[i] = bobHistory[queryArray[i]];
    }

    // send hashes
    response = await partitionInstantiator
      .replyQuery(partitionIndex, queryArray, replyArray,
                  { from: accounts[5], gas: 1500000 })

    expect(getEvent(response, 'HashesPosted')).not.to.be.undefined;

    // mimic a waiting period of 3500 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [3500], id: 0});

    // bob claiming victory should fail
    expect(await getError(
      partitionInstantiator
        .claimVictoryByTime(partitionIndex,
                            { from: accounts[5], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // mimic a waiting period of 200 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [200], id: 0});

    // bob claiming victory should now work
    response = await partitionInstantiator
      .claimVictoryByTime(partitionIndex, { from: accounts[5], gas: 1500000 });
    event = getEvent(response, 'ChallengeEnded');
    expect(+event._state).to.equal(3);

    // check if the state is ClaimerWon
    currentState = await partitionInstantiator.currentState.call(partitionIndex);
    expect(currentState.toNumber()).to.equal(3);
  });
  */
});

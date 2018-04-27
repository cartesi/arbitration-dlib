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

    let hd_position = BigNumber("0x0000000000000000");
    let pc_position = BigNumber("0x4000000000000000");
    let ic_position = BigNumber("0x4000000000000008");
    let oc_position = BigNumber("0x4000000000000010");
    let halted_state = BigNumber("0x4000000000000018");
    let ram_size_position = BigNumber("0x4000000000000020");
    let input_size_position = BigNumber("0x4000000000000028");
    let output_size_position = BigNumber("0x4000000000000030");
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
      // write sizes
      mm.setValue(ram_size_position, "0x0000000000010000");
      mm.setValue(input_size_position, "0x0000000000010000");
      mm.setValue(output_size_position, "0x0000000000010000");
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
    finalTime = 300;

    aliceHistory = [];
    bobHistory = [];
    for (let i = 0; i < 300; i++) {
      aliceHistory.push(aliceMM.merkel());
      bobHistory.push(bobMM.merkel());
      aliceSubleq.step();
      bobSubleq.step();
      if (i == lastAggreement) { bobMM.setValue(ic_position, initial_ic); }
    }
    claimerFinalHash = bobMM.merkel();
  });

  it('Find divergence', async function() {
    // deploy contract and update object
    let mmInstantiator = await MMInstantiator.new();
    let partitionInstantiator = await PartitionInstantiator.new();
    let token = await Token.new({ from: accounts[2] });
    let vgInstantiator = await VGInstantiator.new(
      token.address,
      partitionInstantiator.address,
      mmInstantiator.address
    );
    response = await token.approve(
      vgInstantiator.address, 1000,
      { from: accounts[2], gas: 2000000 });
    event = getEvent(response, 'Approval');
    expect(event).not.to.be.undefined;
    // instantiate a partition
    response = await vgInstantiator.instantiate(
      accounts[0], accounts[1], web3.utils.toWei('1', 'ether'),
      1000, 3600, initialHash, claimerFinalHash, finalTime,
      { from: accounts[2], gas: 2000000,
        value: web3.utils.toWei('1', 'ether') });
    event = getEvent(response, 'VGCreated');
    vgIndex = event._index.toNumber();
    partitionIndex = event._partitionInstance.toNumber();
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
          .claimVictoryByTime(partitionIndex, { from: accounts[0], gas: 1500000 }))
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
          partitionIndex, leftPoint.toString(), { from: accounts[0], gas: 1500000 })
        event = getEvent(response, 'DivergenceFound');
        expect(event).not.to.be.undefined;
        expect(+event._timeOfDivergence).to.equal(lastAggreement);
        // check if the state is DivergenceFound
        currentState = await partitionInstantiator.currentState.call(partitionIndex);
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
    // having found the point of divergence we simulate the machine at that point
    let freshMM = new mm.MemoryManager();
    initMachine(freshMM);
    let freshSubleq = new subleq.Subleq(freshMM)
    freshSubleq.run(lastAggreement);
    // take a snapshot right before dispute
    freshMM.snapshot();
    freshMM.startRecording();
    freshSubleq.step();
    let recordedReads = freshMM.getRecordedReads();
    let recordedWrites = freshMM.getRecordedWrites();
    let finalHash = freshMM.merkel();
    freshMM.restore();
    for (let i = 0; i < recordedReads.length; i++)
    {
      proof = freshMM.generateProof(recordedReads[i][0]);
      response = await mmInstantiator
        .proveValue(mmIndex, recordedReads[i][0].toString(),
                    recordedReads[i][1], proof,
                    { from: accounts[0], gas: 2000000 });
    }
    // finish phase of proving values in memory
    response = await mmInstantiator
      .finishSubmissionPhase(mmIndex,
                             { from: accounts[0], gas: 2000000 });
    // check if memory is in reading phase
    currentState = await mmInstantiator.currentState.call(mmIndex);
    expect(currentState.toNumber()).to.equal(1);
    // run the machine for one step
    response = await vgInstantiator.continueMachineRunChallenge(
      vgIndex, { from: accounts[0], gas: 3000000 });
    // check if memory is in update hash phase
    currentState = await mmInstantiator.currentState.call(mmIndex);
    expect(currentState.toNumber()).to.equal(3);
    // check how many values were writen
    sizeWriteArray = await mmInstantiator
      .getWrittenAddressLength(mmIndex, { from: accounts[0] });
    expect(sizeWriteArray.toNumber()).to.equal(recordedWrites.length);
    // update each hash that was written
    for(let i = sizeWriteArray - 1; i >=0; i--) {
      // address writen
      addressWritten = await mmInstantiator
        .writtenAddress.call(mmIndex, i, { from: accounts[0] });
      oldValue = freshMM.getWord(addressWritten);
      newValue = await mmInstantiator
        .valueWritten.call(mmIndex, addressWritten, { from: accounts[0] });
      proof = freshMM.generateProof(addressWritten);
      response = await mmInstantiator
        .updateHash(mmIndex, proof, { from: accounts[0], gas: 2000000 })
      event = getEvent(response, 'HashUpdated');
      expect(event).not.to.be.undefined;
      expect(event._valueSubmitted).to.equal(newValue);
      freshMM.setValue(addressWritten, newValue);
      // check that false merkel proofs fail
      proof[2] =
        '0xfedc0d0dbbd855c8ead6735448f9b0960e4a5a7cf43b4ef90afe607de7618cae';
      expect(await getError(
        mmInstantiator.updateHash(mmIndex, proof,
                                  { from: accounts[0], gas: 2000000 }))
            ).to.have.string('VM Exception');
    }
    // check final hash
    remoteFinalHash = await mmInstantiator.newHash.call(mmIndex);
    expect(finalHash).to.equal(remoteFinalHash);
    // finishing update hash phase
    response = await mmInstantiator
      .finishUpdateHashPhase(mmIndex, { from: accounts[0], gas: 2000000 })
    expect(getEvent(response, 'FinishedUpdating')).not.to.be.undefined;
    // check if memory is in finished state
    currentState = await mmInstantiator.currentState.call(mmIndex);
    expect(currentState.toNumber()).to.equal(4);
    // check that alice has no balance in ether and no tokens
    response = await vgInstantiator.getBalanceOf.call(accounts[0]);
    expect(response.toNumber()).to.equal(0);
    response = await token.balanceOf(accounts[0]);
    expect(response.toNumber()).to.equal(0);
    let aliceInitialBalance = await web3.eth.getBalance(accounts[0]);
    // finish challange
    response = await vgInstantiator.settleVerificationGame(
      vgIndex, { from: accounts[0], gas: 3000000 });
    event = getEvent(response, "VGFinished");
    expect(event._finalState.toNumber()).to.equal(4);
    // check that alice has a tokens
    response = await token.balanceOf(accounts[0]);
    expect(response.toNumber()).to.equal(1000);
    // check that alice has one ether in vg balance
    response = await vgInstantiator.getBalanceOf.call(accounts[0]);
    expect(response.toString()).to.equal(web3.utils.toWei('1', 'ether'));
    // withdraw alice's balance
    await vgInstantiator.withdraw({ from: accounts[0] });
    // check that alice has no ether in vg balance
    response = await vgInstantiator.getBalanceOf.call(accounts[0]);
    expect(response.toNumber()).to.equal(0);
    // check that alice has one ether in her wallet
    let aliceFinalBalance = await web3.eth.getBalance(accounts[0]);
    expect(Number(aliceFinalBalance))
      .to.be.above(Number(aliceInitialBalance)
                   + Number(web3.utils.toWei('0.9', 'ether')));
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

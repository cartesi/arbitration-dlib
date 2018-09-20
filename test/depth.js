const BigNumber = require('bignumber.js');
const Web3 = require('web3');

const mm = require('../subleq/mm.js');
const expect = require('chai').expect;
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;
const sendRPC = require('../utils/tools.js').sendRPC;

var web3 = new Web3('http://127.0.0.1:9545');

var DepthInterface = artifacts.require("./DepthInterface.sol");

var aliceMM = new mm.MemoryManager();
var bobMM = new mm.MemoryManager();

var zero = BigNumber('0');
var small = BigNumber('1024');
var large = BigNumber('18446744073709551360');

contract('DepthInterface', function(accounts) {
  beforeEach(function() {

    values = {
      '0': '0x1111111111111111',
      '8': '0x1111111111111111',
      '16': '0x1111111111111111',
      '24': '0x1111111111111111',
      '1024': '0x1111111111111111',
      '1032': '0x1111111111111111',
      '1040': '0x1111111111111111',
      '1048': '0x1111111111111111',
      '18446744073709551360': '0x1111111111111111',
      '18446744073709551368': '0x1111111111111111',
      '18446744073709551376': '0x1111111111111111',
      '18446744073709551384': '0x1111111111111111'
    }
    for (key in values) {
      aliceMM.setWord(key, values[key]);
      bobMM.setWord(key, values[key]);
    }
    bobMM.setWord('18446744073709551368', '0x1111111111111112');

    roundDuration = 3600;
  });

  it('Find divergence', async function() {
    // deploy contract and update object
    let depthInterface = await DepthInterface
        .new(accounts[0], accounts[1], bobMM.merkel(), roundDuration,
             { from: accounts[2], gas: 2000000 });

    let leftHash, rightHash;

    while (true) {
      // check if the state is WaitingHashes
      currentState = await depthInterface.currentState.call();
      expect(currentState.toNumber()).to.equal(1);

      currentDepth = await depthInterface.currentDepth.call();

      currentAddress = await depthInterface.currentAddress.call();
      currentSize = BigNumber(2).pow(63 - currentDepth);
      currentLeftAddress = BigNumber(currentAddress);
      currentRightAddress = currentLeftAddress.plus(currentSize);

      // get the hashes of children and prepare response
      leftHash = bobMM.subMerkel(bobMM.memoryMap, currentLeftAddress,
                                 60 - currentDepth);
      rightHash = bobMM.subMerkel(bobMM.memoryMap, currentRightAddress,
                                 60 - currentDepth);


      // sending hashes from alice should fail
      expect(await getError(
        depthInterface.replyQuery(leftHash, rightHash,
                                  { from: accounts[0], gas: 1500000 }))
            ).to.have.string('VM Exception');

      // alice claiming victory should fail
      expect(await getError(
        depthInterface.claimVictoryByTime({ from: accounts[0], gas: 1500000 }))
            ).to.have.string('VM Exception');

      // send hashes
      response = await depthInterface
        .replyQuery(leftHash, rightHash,
                    { from: accounts[1], gas: 1500000 })
      event = getEvent(response, 'HashesPosted');
      expect(event).not.to.be.undefined;

      // get the hashes of children in alice memory to prepare query
      leftHash = aliceMM.subMerkel(aliceMM.memoryMap, currentLeftAddress,
                                   60 - currentDepth);
      rightHash = aliceMM.subMerkel(aliceMM.memoryMap, currentRightAddress,
                                    60 - currentDepth);
      // decide where to turn
      claimerLeftHash = await depthInterface.claimerLeftChildHash.call();
      claimerRightHash = await depthInterface.claimerRightChildHash.call();
      let continueToTheLeft = false;
      let differentHash;
      if (claimerLeftHash === leftHash) {
        continueToTheLeft = false;
        differentHash = claimerRightHash;
      } else {
        continueToTheLeft = true;
        differentHash = claimerLeftHash;
      }

      // check if the state is WaitingQuery
      currentState = await depthInterface.currentState.call();
      expect(currentState.toNumber()).to.equal(0);

      // bob claiming victory should fail
      expect(await getError(
        depthInterface.claimVictoryByTime({ from: accounts[1], gas: 1500000 }))
            ).to.have.string('VM Exception');

      // send query with last queried time of aggreement
      response = await depthInterface
        .makeQuery(continueToTheLeft, differentHash,
                   { from: accounts[0], gas: 1500000 })
      expect(getEvent(response, 'QueryPosted')).not.to.be.undefined;

      // if the state is WaitingControversialPhrase, exit while loop
      // check if the state is WaitingQuery
      currentState = await depthInterface.currentState.call();
      if (currentState.toNumber() === 4) break;
    }
    currentAddress = await depthInterface.currentAddress.call();
    currentAddress = BigNumber(currentAddress);

    let word1 = bobMM.getWord(currentAddress);
    let word2 = bobMM.getWord(currentAddress.plus(8));
    let word3 = bobMM.getWord(currentAddress.plus(16));
    let word4 = bobMM.getWord(currentAddress.plus(24));
    // send controversial hash
    response = await depthInterface
      .postControversialPhrase(word1, word2, word3, word4,
                               { from: accounts[1], gas: 1500000 })
    expect(getEvent(response, 'ControversialPhrasePosted')).not.to.be.undefined;

    // check if the state is WaitingQuery
    currentState = await depthInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(5);

    divergingAddress = await depthInterface.currentAddress.call();
    expect(divergingAddress.toString()).to.equal(large.toString());
  });

  it('Claimer timeout', async function() {
    // deploy contract and update object
    let depthInterface = await DepthInterface
        .new(accounts[0], accounts[1], bobMM.merkel(), roundDuration,
             { from: accounts[2], gas: 2000000 });

    // check if the state is WaitingHashes
    currentState = await depthInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(1);

    // mimic a waiting period of 3500 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [3500], id: 0});

    // alice claiming victory should fail
    expect(await getError(
      depthInterface.claimVictoryByTime({ from: accounts[0], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // mimic a waiting period of 200 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [200], id: 0});

    // alice claiming victory should now work
    response = await depthInterface
      .claimVictoryByTime({ from: accounts[0], gas: 1500000 });
    event = getEvent(response, 'ChallengeEnded');
    expect(+event.theState.toNumber()).to.equal(2);

    // check if the state is ChallengerWon
    currentState = await depthInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(2);
  });

  it('Challenger timeout', async function() {
    // deploy contract and update object
    let depthInterface = await DepthInterface
        .new(accounts[0], accounts[1], bobMM.merkel(), roundDuration,
             { from: accounts[2], gas: 2000000 });

    // check if the state is WaitingHashes
    currentState = await depthInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(1);

    currentDepth = await depthInterface.currentDepth.call();
    currentAddress = await depthInterface.currentAddress.call();
    currentSize = BigNumber(2).pow(63 - currentDepth);
    currentLeftAddress = BigNumber(currentAddress);
    currentRightAddress = currentLeftAddress.plus(currentSize);

    // get the hashes of children and prepare response
    leftHash = bobMM.subMerkel(bobMM.memoryMap, currentLeftAddress,
                               60 - currentDepth);
    rightHash = bobMM.subMerkel(bobMM.memoryMap, currentRightAddress,
                                60 - currentDepth);

    // alice claiming victory should fail
    expect(await getError(
      depthInterface.claimVictoryByTime({ from: accounts[0], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // send hashes
    response = await depthInterface
      .replyQuery(leftHash, rightHash,
                  { from: accounts[1], gas: 1500000 })
    event = getEvent(response, 'HashesPosted');
    expect(event).not.to.be.undefined;

    // check if the state is WaitingQuery
    currentState = await depthInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(0);

    // mimic a waiting period of 3500 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [3500], id: 0});

    // bob claiming victory should fail
    expect(await getError(
      depthInterface.claimVictoryByTime({ from: accounts[1], gas: 1500000 }))
          ).to.have.string('VM Exception');

    // mimic a waiting period of 200 seconds
    response = await sendRPC(web3, {jsonrpc: "2.0", method: "evm_increaseTime",
                                    params: [200], id: 0});

    // bob claiming victory should now work
    response = await depthInterface
      .claimVictoryByTime({ from: accounts[1], gas: 1500000 });
    event = getEvent(response, 'ChallengeEnded');
    expect(+event.theState).to.equal(3);

    // check if the state is ClaimerWon
    currentState = await depthInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(3);
  });
});

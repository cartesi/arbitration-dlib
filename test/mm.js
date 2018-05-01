const BigNumber = require('bignumber.js');
const expect = require('chai').expect;

const mm = require('../utils/mm.js');
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;
const twoComplement32 = require('../utils/tools.js').twoComplement32;

var MMInstantiator = artifacts.require("./MMInstantiator.sol");

contract('MMInstantiator', function(accounts) {
  it('Checking functionalities', async function() {
    // prepare memory
    let index;
    let myMM = new mm.MemoryManager();
    let initialValues = { '0':                    '0x0000000000300001',
                          '180008':               '0x000000000000c030',
                          '18446744073709551608': '0x00000000000f00a0',
                 };
    let currentState;
    let proof;

    let updates = [
      { 'wasRead': true, 'position': '0'},
      { 'wasRead': false, 'position': '0', 'value': '0x000000000030000c'},
      { 'wasRead': true, 'position': '0'},
      { 'wasRead': true, 'position': '8'},
      { 'wasRead': true, 'position': '180008'},
      { 'wasRead': false, 'position': '180008', 'value': '0x000000000030000f'},
      { 'wasRead': true, 'position': '18446744073709551608'},
      { 'wasRead': false, 'position': '8', 'value': '0x000000000030000c'},
      { 'wasRead': false, 'position': '16', 'value': '0x000000000030000c'},
      { 'wasRead': true, 'position': '180008'},
    ]

    for (key in initialValues) {
      myMM.setValue(key, initialValues[key])
    }
    initialHash = myMM.merkel()

    // launch contract from account[2], who will be the owner
    let mmInstantiator = await MMInstantiator.new();
    response = await mmInstantiator.instantiate(
      accounts[0], accounts[1], initialHash,
      { from: accounts[2], gas: 2000000 });
    event = getEvent(response, 'MemoryCreated');
    expect(event._index.toNumber()).to.equal(0);
    index = 0;

    // contract should start waiting for values to be inserted
    currentState = await mmInstantiator.currentState.call(index);
    expect(currentState.toNumber()).to.equal(0);

    // cannot submit un-aligned address
    proof = myMM.generateProof(0);
    expect(await getError(
      mmInstantiator.proveRead(index, 4, '0x0000000000000000', proof,
                               { from: accounts[0], gas: 2000000 }))
          ).to.have.string('VM Exception');

    // other users cannot submit
    proof = myMM.generateProof(888);
    expect(await getError(
      mmInstantiator.proveRead(index, 888, '0x0000000000000000', proof,
                               { from: accounts[4], gas: 2000000 }))
          ).to.have.string('VM Exception');

    // prove that the values in initial memory are correct
    for (let j = 0; j < updates.length; j++) {
      u = updates[j];
      // generate proof of value
      proof = myMM.generateProof(u.position);
      if (u.wasRead) {
        // submit read
        response = await mmInstantiator
          .proveRead(index, u.position, myMM.getWord(u.position), proof,
                     { from: accounts[0], gas: 2000000 });
        event = getEvent(response, 'ValueProved');
        expect(event._wasRead).to.be.true;
        expect(event._position.toString()).to.equal(u.position);
        expect(event._value.toString()).to.equal(
          twoComplement32(myMM.getWord(u.position)));
      } else {
        // submit write
        response = await mmInstantiator
          .proveWrite(index, u.position, myMM.getWord(u.position),
                      twoComplement32(u.value), proof,
                      { from: accounts[0], gas: 2000000 });
        event = getEvent(response, 'ValueProved');
        expect(event._wasRead).to.be.false;
        expect(event._position.toString()).to.equal(u.position);
        expect(event._value.toString()).to.equal(u.value);
        myMM.setValue(u.position, u.value);
        response = await mmInstantiator.newHash.call(index);
        expect(response).to.equal(myMM.merkel());
      }
    }

    let replayMM = new mm.MemoryManager();
    for (key in initialValues) {
      replayMM.setValue(key, initialValues[key])
    }

    // finish proof phase
    response = await mmInstantiator
      .finishProofPhase(index, { from: accounts[0], gas: 2000000 });

    // prove that the values in initial memory are correct
    for (let j = 0; j < updates.length; j++) {
      u = updates[j];
      // generate proof of value
      if (u.wasRead) {
        // submit read
        response = await mmInstantiator
          .read(index, u.position,
                { from: accounts[1], gas: 2000000 });
        event = getEvent(response, 'ValueRead');
        expect(event._position.toString()).to.equal(u.position);
        expect(event._value.toString()).to.equal(
          replayMM.getWord(u.position));
      } else {
        // submit write
        replayMM.setValue(u.position, u.value);
        response = await mmInstantiator
          .write(index, u.position,
                 twoComplement32(u.value),
                 { from: accounts[1], gas: 2000000 });
        event = getEvent(response, 'ValueWritten');
        expect(event._position.toString()).to.equal(u.position);
        expect(event._value.toString()).to.equal(u.value);
      }
    }

    // finishing replay phase
    response = await mmInstantiator
      .finishReplayPhase(index, { from: accounts[1], gas: 2000000 })
    expect(getEvent(response, 'FinishedReplay')).not.to.be.undefined;

    // check final hash
    finalHash = myMM.merkel();
    remoteFinalHash = await mmInstantiator.newHash.call(index);
    expect(finalHash).to.equal(remoteFinalHash);

    // check if contract is in finished state
    currentState = await mmInstantiator.currentState.call(index);
    expect(currentState.toNumber()).to.equal(2);
  })
})

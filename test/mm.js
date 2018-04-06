const BigNumber = require('bignumber.js');
const expect = require('chai').expect;

const mm = require('../utils/mm.js');
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;

var MMInterface = artifacts.require("./MMInterface.sol");

contract('MMInterface', function(accounts) {
  it('Checking functionalities', async function() {
    // prepare memory
    let myMM = new mm.MemoryManager();
    let values = { '0':                    '0x0000000000300001',
                   '180008':               '0x000000000000c030',
                   '18446744073709551608': '0x00000000000f00a0',
                 };
    let currentState;
    let proof;

    for (key in values) {
      myMM.setValue(key, values[key])
    }
    initialHash = myMM.merkel()

    // launch contract from account[2], who will be the owner
    let mmInterface = await MMInterface
        .new(accounts[0], accounts[1], initialHash,
             { from: accounts[2], gas: 2000000 });

    // only owner should be able to kill contract
    expect(await getError(
      mmInterface.kill({ from: accounts[0], gas: 2000000 }))
          ).to.have.string('VM Exception');

    // contract should start waiting for values to be inserted
    currentState = await mmInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(0);

    // prove that the values in initial memory are correct
    for (key in values) {
      // check that key was not marked as submitted
      wasSubmitted = await mmInterface.addressWasSubmitted.call(key);
      expect(wasSubmitted).to.be.false;
      // generate proof of value
      proof = myMM.generateProof(key);
      // submit merkel proof to manager contract
      response = await mmInterface
        .proveValue(key, values[key], proof,
                    { from: accounts[0], gas: 2000000 });
      event = getEvent(response, 'ValueSubmitted');
      expect(event.addressSubmitted.toString()).to.equal(key);
      expect(event.valueSubmitted.toString()).to.equal(values[key]);
      // check that key was marked as submitted
      wasSubmitted = await mmInterface
        .addressWasSubmitted
        .call(key, { from: accounts[1], gas: 2000000 });
      expect(wasSubmitted).to.be.true;
    }

    // prove that other addresses still have zeros on them
    // we also test that false merkel proofs fail
    other_values = { '283888':               '0x0000000000000000',
                     '18446744073709551600': '0x0000000000000000',
                     '2838918800':           '0x0000000000000000'
                   };

    for (key in other_values) {
      // generate proof of a certain value with zero
      proof = myMM.generateProof(key);
      // submit merkel proof to manager contract
      response = await mmInterface
        .proveValue(key, other_values[key], proof,
                    { from: accounts[0], gas: 2000000 });
      expect(getEvent(response, 'ValueSubmitted')).not.to.be.undefined;
      // alter proof and test for error
      proof[2] =
        '0xfedc0d0dbbd855c8ead6735448f9b0960e4a5a7cf43b4ef90afe607de7618cae';
      expect(await getError(
        mmInterface.proveValue(key, other_values[key], proof,
                               { from: accounts[0], gas: 2000000 }))
            ).to.have.string('VM Exception');
    }

    // cannot submit un-aligned address
    proof = myMM.generateProof(0);
    expect(await getError(
      mmInterface.proveValue(4, '0x0000000000000000', proof,
                             { from: accounts[0], gas: 2000000 }))
          ).to.have.string('VM Exception');

    // other users cannot submit
    proof = myMM.generateProof(888);
    expect(await getError(
      mmInterface.proveValue(888, '0x0000000000000000', proof,
                              { from: accounts[4], gas: 2000000 }))
          ).to.have.string('VM Exception');

    // finishing submission phase
    response = await mmInterface
      .finishSubmissionPhase({ from: accounts[0], gas: 2000000 })
    expect(getEvent(response, 'FinishedSubmittions')).not.to.be.undefined;

    // check if contract is in read phase
    currentState = await mmInterface.currentState()
    expect(currentState.toNumber()).to.equal(1);

    // check values submited
    for (key in values) {
      // check that it was submitted
      wasSubmitted = await mmInterface.addressWasSubmitted
        .call(key, { from: accounts[1], gas: 2000000 });
      // reading values on memory manager contract
      response = await mmInterface.read
        .call(key, { from: accounts[1], gas: 2000000 });
      expect(response).to.equal(values[key].toString());
    }

    // overwrite some new values to memory
    write_values = { '283888':               '0x0000000000000000',
                     '180008':               '0x0a000e000000c030',
                     '18446744073709551608': '0x00000000000f00a0',
                     '2838918800':           '0xffffffffffffffff'
                   };
    // write values in mm
    for (key in write_values) {
      // write values to memory manager contract
      response = await mmInterface
        .write(key, write_values[key], { from: accounts[1], gas: 2000000 });
      expect(getEvent(response, 'ValueWritten')).not.to.be.undefined;
    }

    // finishing write phase
    response = await mmInterface
      .finishWritePhase({ from: accounts[1], gas: 2000000 })
    expect(getEvent(response, 'FinishedWriting')).not.to.be.undefined;

    // check if contract is in update hash phase
    currentState = await mmInterface.currentState();
    expect(currentState.toNumber()).to.equal(3);

    // check how many values were writen
    sizeWriteArray = await mmInterface
      .getWrittenAddressLength({ from: accounts[0] });
    expect(sizeWriteArray.toNumber())
      .to.equal(Object.keys(write_values).length);

    // update each hash that was written
    for(let i = sizeWriteArray - 1; i >=0; i--) {
      // address writen
      addressWritten = await mmInterface
        .writtenAddress(i, { from: accounts[0] });
      oldValue = myMM.getWord(addressWritten);
      newValue = await mmInterface
        .valueWritten(addressWritten, { from: accounts[0] });
      proof = myMM.generateProof(addressWritten);
      response = await mmInterface
        .updateHash(proof, { from: accounts[0], gas: 2000000 })
      event = getEvent(response, 'HashUpdated');
      expect(event).not.to.be.undefined;
      expect(event.valueSubmitted).to.eql(newValue);
      myMM.setValue(addressWritten, newValue);

      // check that false merkel proofs fail
      proof[2] =
        '0xfedc0d0dbbd855c8ead6735448f9b0960e4a5a7cf43b4ef90afe607de7618cae';
      expect(await getError(
        mmInterface.updateHash(proof, { from: accounts[0], gas: 2000000 }))
            ).to.have.string('VM Exception');
    }

    // check final hash
    finalHash = myMM.merkel();
    remoteFinalHash = await mmInterface.newHash();
    expect(finalHash).to.equal(remoteFinalHash);

    // finishing update hash phase
    response = await mmInterface
      .finishUpdateHashPhase({ from: accounts[0], gas: 2000000 })
    expect(getEvent(response, 'Finished')).not.to.be.undefined;

    // check if contract is in finished state
    currentState = await mmInterface.currentState();
    expect(currentState.toNumber()).to.equal(4);

    // kill contract
    response = await mmInterface.kill({ from: accounts[2], gas: 2000000 });

    // check if contract was killed
    [error, currentState] = await unwrap(mmInterface.currentState());
    expect(error.message).to.have.string('not a contract address');;
  })
})

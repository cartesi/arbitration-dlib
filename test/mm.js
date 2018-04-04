const mm = require('../utils/mm.js');
const BigNumber = require('bignumber.js');

var expect = require('chai').expect;
var getEvent = require('../utils/tools.js').getEvent;

function hashWord(word) {
    return web3.utils.soliditySha3({type: 'uint64', value: word});
}

var MMInterface = artifacts.require("./MMInterface.sol");

function unwrap(promise) {
   return promise.then(data => {
      return [null, data];
   })
   .catch(err => [err]);
}

contract('MMInterface', function(accounts) {
  it('Checking functionalities', async function() {
    //this.timeout(150000)

    // prepare memory
    let myMM = new mm.MemoryManager();
    let values = { '0':                    '0x0000000000300001',
                   '180008':               '0x000000000000c030',
                   '18446744073709551608': '0x00000000000f00a0',
                 };
    for (key in values) {
      myMM.setValue(key, values[key])
    }
    initialHash = myMM.merkel()

    // launch contract from account[2], who will be the owner
    let mmInterface = await MMInterface
        .new(accounts[0], accounts[1], initialHash,
             { from: accounts[2], gas: 2000000 });

    // only owner should be able to kill contract
    [error, response] = await unwrap(
      mmInterface.kill({ from: accounts[0], gas: 2000000 })
    );
    expect(error.message).to.have.string('VM Exception');;

    // contract should start waiting for values to be inserted
    let currentState = await mmInterface.currentState.call();
    expect(currentState.toNumber()).to.equal(0);

    // prove that the values in initial memory are correct
    for (key in values) {
      // check that key was not marked as submitted
      wasSubmitted = await mmInterface.addressWasSubmitted.call(key);
      expect(wasSubmitted).to.be.false;
      // generate proof of value
      let proof = myMM.generateProof(key);
      // proving values on memory manager contract
      response = await mmInterface
        .proveValue(key, values[key], proof,
                    { from: accounts[0], gas: 2000000 });
      returnValues = getEvent(response, 'ValueSubmitted');
      expect(returnValues.addressSubmitted.toString()).to.equal(key);
      expect(returnValues.valueSubmitted.toString()).to.equal(values[key]);
      // check that key was marked as submitted
      wasSubmitted = await mmInterface
        .addressWasSubmitted
        .call(key, { from: accounts[1], gas: 2000000 });
      expect(wasSubmitted).to.be.true;
    }

    other_values = { '283888':               '0x0000000000000000',
                     '18446744073709551600': '0x0000000000000000',
                     '2838918800':           '0x0000000000000000'
                   };

    // prove some zeros that were not inserted before and test for false proofs
    for (key in other_values) {
      // generate proof of value
      let proof = myMM.generateProof(key);
      // prove values on memory manager contract
      response = await mmInterface
        .proveValue(key, other_values[key], proof,
                    { from: accounts[0], gas: 2000000 });
      expect(getEvent(response, 'ValueSubmitted')).not.to.be.undefined;
      // alter proof and test for error
      proof[2] =
        '0xfedc0d0dbbd855c8ead6735448f9b0960e4a5a7cf43b4ef90afe607de7618cae';
      [error, response] = await unwrap(mmInterface
        .proveValue(key, other_values[key], proof,
                    { from: accounts[0], gas: 2000000 }));
      expect(error.message).to.have.string('VM Exception');

    }

    // cannot submit un-aligned address
    let proof = myMM.generateProof(0);
    [error, response] = await unwrap(mmInterface
      .proveValue(4, '0x0000000000000000', proof,
                  { from: accounts[0], gas: 2000000 }))
    expect(error.message).to.have.string('VM Exception');

    // other user cannot submit
    proof = myMM.generateProof(888);
    [error, response] = await unwrap(mmInterface
      .proveValue(888, '0x0000000000000000', proof,
                  { from: accounts[4], gas: 2000000 }))
    expect(error.message).to.have.string('VM Exception');

    // finishing submissions
    response = await mmInterface
      .finishSubmissionPhase({ from: accounts[0], gas: 2000000 })
    expect(getEvent(response, 'FinishedSubmittions')).not.to.be.undefined;

    // check if read phase
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

    // write some values to memory
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

    // check if update hash phase
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
      let returnedEvent = getEvent(response, 'HashUpdated');
      expect(returnedEvent).not.to.be.undefined;
      expect(returnedEvent['valueSubmitted']).to.eql(newValue);
      myMM.setValue(addressWritten, newValue);
    }

    // check final hash
    finalHash = myMM.merkel();
    remoteFinalHash = await mmInterface.newHash();
    expect(finalHash).to.equal(remoteFinalHash);

    // finishing update hash phase
    response = await mmInterface
      .finishUpdateHashPhase({ from: accounts[0], gas: 2000000 })
    expect(getEvent(response, 'Finished')).not.to.be.undefined;

    // check if we are at the finished phase
    currentState = await mmInterface.currentState();
    expect(currentState.toNumber()).to.equal(4);

    // kill contract
    response = await mmInterface.kill({ from: accounts[2], gas: 2000000 });

    // check if contract was killed
    [error, currentState] = await unwrap(mmInterface.currentState());
    expect(error.message).to.have.string('not a contract address');;

  })
})

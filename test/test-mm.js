const mm = require('../utils/mm.js')
const BigNumber = require('bignumber.js');

require('chai/register-expect');

function hashWord(word) {
    return web3.utils.soliditySha3({type: 'uint64', value: word});
}

var MMInterface = artifacts.require("./MMInterface.sol");

contract('MMInterface', function(accounts) {
  it('Checking functionalities', function() {
    //this.timeout(150000)
    // prepare memory

    let myMM = new mm.MemoryManager();
    let zeros = myMM.merkel();
    let small = BigNumber('120')
    let large = BigNumber('18446744073709551608');
    let large_string = large.toString();

    let values = { '0':                    '0x0000000000300000',
                   '18446744073709551608': '0x00000000000f0000',
                   '1808':                 '0x000000000000c000'
                 };

    for (key in values) {
      myMM.setValue(key, values[key])
    }
    initialHash = myMM.merkel()

    var mmInterface;

    return MMInterface.deployed().then(function(instance) {
      mmInterface = instance;
      return mmInterface.currentState.call();
    }).then(function(currentState) {
      console.log(currentState.toNumber());
      expect(currentState.toNumber()).to.equal(0);
    });




    
  })
})
/*

    // prove that the values in initial memory are correct
    for (key in values) {
      // check that key was not marked as submitted
      wasSubmitted = yield MMInterface.methods
        .addressWasSubmitted(key)
        .call({ from: accounts[1], gas: 2000000 });
      expect(wasSubmitted).to.be.false;
      // generate proof of value
      let proof = myMM.generateProof(key);
      // proving values on memory manager contract
      response = yield MMInterface.methods
        .proveValue(key, values[key], proof)
        .send({ from: accounts[0], gas: 2000000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueSubmitted).not.to.be.undefined;
        });
      returnValues = response.events.ValueSubmitted.returnValues;
      // check that key was marked as submitted
      wasSubmitted = yield MMInterface.methods
        .addressWasSubmitted(key)
        .call({ from: accounts[1], gas: 2000000 });
      expect(wasSubmitted).to.be.true;
    }


    other_values = { '283888':       '0x0000000000000000',
                     '282343888':    '0x0000000000000000',
                     '2838918800':   '0x0000000000000000'
                   };

    // prove some more (some that were not inserted in myMM)
    for (key in other_values) {
      // generate proof of value
      let proof = myMM.generateProof(key);
      // prove values on memory manager contract
      response = yield MMInterface.methods
        .proveValue(key, other_values[key], proof)
        .send({ from: accounts[0], gas: 2000000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueSubmitted).not.to.be.undefined;
        });
      returnValues = response.events.ValueSubmitted.returnValues;
      //console.log(returnValues);
    }

    // cannot submit un-aligned address
    let proof = myMM.generateProof(0);
    response = yield MMInterface.methods
      .proveValue(4, '0x0000000000000000', proof)
      .send({ from: accounts[0], gas: 2000000 })
      .catch(function(error) {
        expect(error.message).to.have.string('VM Exception');
      });
    // finishing submissions
    response = yield MMInterface.methods
      .finishSubmissionPhase()
      .send({ from: accounts[0], gas: 2000000 })
      .on('receipt', function(receipt) {
        expect(receipt.events.FinishedSubmittions).not.to.be.undefined;
      });

    // check if read phase
    currentState = yield MMInterface.methods
      .currentState().call({ from: accounts[0] });
    expect(currentState).to.equal('1');
    for (key in values) {
      // check that it waas submitted
      wasSubmitted = yield MMInterface.methods
        .addressWasSubmitted(key)
        .call({ from: accounts[1], gas: 2000000 });
      // reading values on memory manager contract
      response = yield MMInterface.methods
        .read(key)
        .call({ from: accounts[1], gas: 2000000 });
      expect(response).to.equal(values[key].toString());
    }
    write_values = { '283888':        '0x0000000000000000',
                     '1808':          '0x0000f000f0000000',
                     '2838918800':    '0xffffffffffffffff'
                   };
    // write values in mm
    for (key in write_values) {
      // write values to memory manager contract
      response = yield MMInterface.methods
        .write(key, write_values[key])
        .send({ from: accounts[1], gas: 2000000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.ValueWritten).not.to.be.undefined;
        });
      returnValues = response.events.ValueWritten.returnValues;
    }

    // finishing write phase
    response = yield MMInterface.methods
      .finishWritePhase()
      .send({ from: accounts[1], gas: 2000000 })
      .on('receipt', function(receipt) {
        expect(receipt.events.FinishedWriting).not.to.be.undefined;
      });

    // check if update hash phase
    currentState = yield MMInterface.methods
      .currentState().call({ from: accounts[0] });
    expect(currentState).to.equal('3');

    // check how many values were writen
    sizeWriteArray = yield MMInterface.methods
      .getWrittenAddressLength().call({ from: accounts[0] });
    // update each hash
    for(let i = sizeWriteArray - 1; i >=0; i--) {
      // address writen
      addressWritten = yield MMInterface.methods
        .writtenAddress(i).call({ from: accounts[0] });
      //console.log(addressWritten);
      oldValue = myMM.getWord(addressWritten);
      newValue = yield MMInterface.methods
        .valueWritten(addressWritten).call({ from: accounts[0] });
      proof = myMM.generateProof(addressWritten);
      response = yield MMInterface.methods
        .updateHash(proof)
        .send({ from: accounts[0], gas: 2000000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.HashUpdated).not.to.be.undefined;
        });
      returnValues = response.events.HashUpdated.returnValues;
      expect(returnValues.valueSubmitted).to.equal(newValue);
      myMM.setValue(addressWritten, newValue);
    }

    finalHash = myMM.merkel();
    remoteFinalHash = yield MMInterface.methods
      .newHash().call({ from: accounts[0] });
    expect(finalHash).to.equal(remoteFinalHash);

    // finishing update hash phase
    response = yield MMInterface.methods
      .finishUpdateHashPhase()
      .send({ from: accounts[0], gas: 2000000 })
      .on('receipt', function(receipt) {
        expect(receipt.events.Finished).not.to.be.undefined;
      });

    // check if we are at the finished phase
    currentState = yield MMInterface.methods
      .currentState().call({ from: accounts[0] });
    expect(currentState).to.equal('4');

    // kill contract
    response = yield MMInterface.methods.kill()
      .send({ from: accounts[0], gas: 2000000 });
  });
});



*/

const mm = require('../../subleq/mm.js')
var BigNumber = require('bignumber.js');

const expect = require("chai").expect;

describe('Testing memory manager', function() {
  it('Basic tests', function() {
    let myMM = new mm.MemoryManager();
    let zeros = myMM.merkel();
    let small = '120';
    let large = '18446744073709551608';
    // unaligned should throw
    expect(function () { myMM.setWord('1', 0) }).to.throw();
    // negative should throw
    expect(function () { myMM.setWord('-8', 0) }).to.throw();
    // out of range should throw
    expect(function () { myMM.setWord('18446744073709551616', 0) }).to.throw();

    myMM.setWord(small, 0);
    expect(zeros).to.equal(myMM.merkel(), "Set zero to small does not change hash");
    myMM.setWord(large, 0);
    expect(zeros).to.equal(myMM.merkel(), "Set zero to large does not change hash");
    myMM.setWord(large, 1);
    expect(myMM.getWord(large)).to.equal("0x0000000000000001");
    ones = myMM.merkel();
    expect(zeros).not.to.equal(ones, "Set one to large does not change hash");
    myMM.setWord(large, 0);
    expect(zeros).to.equal(myMM.merkel(), "Restore value and hash");
  });
  it('Testing proofs', function() {
    this.timeout(3000);

    let myMM = new mm.MemoryManager();
    let zeros = myMM.merkel();
    let small = BigNumber('120')
    let large = BigNumber('18446744073709551608');
    let proof = myMM.generateProof('11111111111111111000')["siblings"];
    let extract_proof = [];
    for(let i in proof)
    {
      extract_proof.push(proof[i]["hash"]);
    }

    expect(myMM.verifyProof('11111111111111111000', 0, extract_proof)).to.be.true;
    expect(myMM.verifyProof('11111111111111111000', 1, extract_proof)).to.be.false;

    values = { '0': 1,
               '8': 1,
               '16': 1234
             };
    for (key in values) {
      myMM.setWord(key, values[key]);
      proof = myMM.generateProof(key)["siblings"];
      extract_proof = [];
      for(let i in proof)
      {
        extract_proof.push(proof[i]["hash"]);
      }
      expect(myMM.verifyProof(key, values[key], extract_proof)).to.be.true;
    }

    values = { '0': 1,
               '8': 119,
               '11232': 134
             };
    for (key in values) {
      myMM.setWord(key, values[key]);
      proof = myMM.generateProof(key)["siblings"];
      extract_proof = [];
      for(let i in proof)
      {
        extract_proof.push(proof[i]["hash"]);
      }
      expect(myMM.verifyProof(key, values[key], extract_proof)).to.be.true;
    }
  });
});




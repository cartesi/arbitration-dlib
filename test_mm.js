const mocha = require('mocha')
const mm = require('../utils/mm.js')
//var Uint64BE = require("int64-buffer").Uint64BE;
const BigNumber = require('bignumber.js');


const chai = require("chai");
chai.config.includeStack = true;
const expect = chai.expect;
const assert = chai.assert;

describe('Testing memory manager', function() {
    it('Basic tests', function() {
        let myMM = new mm.MemoryManager();
        let zeros = myMM.merkel();
        let small = BigNumber('120')
        let large = BigNumber('18446744073709551608');
        myMM.setValue(small, 0);
        expect(function () { myMM.setValue('1', 0) }).to.throw();
        expect(function () { myMM.setValue('-8', 0) }).to.throw();
        expect(function () { myMM.setValue('18446744073709551616', 0) }).to.throw();
        expect(zeros).to.equal(myMM.merkel(), "Set zero to small changes hash");
        myMM.setValue(large, 0);
        expect(zeros).to.equal(myMM.merkel(), "Set zero to large changes hash");
        myMM.setValue(large, 1);
        expect(myMM.getWord(large)).to.equal(1);
        ones = myMM.merkel();
        expect(zeros).not.to.equal(ones, "Set one to large keeps hash");
        myMM.setValue(large, 0);
        expect(zeros).to.equal(myMM.merkel(), "Restore value not restore hash");
    });
    it('Testing proofs', function() {
        this.timeout(3000);

        let myMM = new mm.MemoryManager();
        let zeros = myMM.merkel();
        let small = BigNumber('120')
        let large = BigNumber('18446744073709551608');
        //myMM.setValue(small, 0);
        let proof = myMM.generateProof('11111111111111111000');
        //console.log(proof);
        expect(myMM.verifyProof('11111111111111111000', 0, proof)).to.be.true;
        expect(myMM.verifyProof('11111111111111111000', 1, proof)).to.be.false;

        myMM.setValue('0', 1);
        proof = myMM.generateProof('0');
        expect(myMM.verifyProof('0', 1, proof)).to.be.true;

        myMM.setValue('8', 1);
        proof = myMM.generateProof('8');
        expect(myMM.verifyProof('8', 1, proof)).to.be.true;

        myMM.setValue('16', 1);
        proof = myMM.generateProof('16');
        expect(myMM.verifyProof('16', 1, proof)).to.be.true;

        myMM.setValue('16', 0);
        proof = myMM.generateProof('16');
        expect(myMM.verifyProof('16', 0, proof)).to.be.true;

        myMM.setValue(large, 1);
        proof = myMM.generateProof(large);
        expect(myMM.verifyProof(large, 1, proof)).to.be.true;
    });
});




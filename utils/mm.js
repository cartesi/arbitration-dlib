const Web3 = require('web3');
var BigNumber = require('bignumber.js');

// var Uint64BE = require("int64-buffer").Uint64BE;

w3 = new Web3();

// returns whether an object is empty
function isEmpty(obj) {
    return Object.keys(obj).length === 0;
}

function hashWord(word) {
  return w3.utils.soliditySha3({type: 'uint64', value: word});
}

class MemoryManager {

    constructor() {
        // initialize an array of iterated keccaks of a zero byte
        this.iteratedZeroHashes = [hashWord(0)];
        for (var i = 0; i < 61; i++) {
            this.iteratedZeroHashes.push(w3.utils.sha3(
                this.iteratedZeroHashes[i]
                + this.iteratedZeroHashes[i].replace(/^0x/, ''))
            );
        }
        //console.log(this.iteratedZeroHashes);
        //   memory - a hash table where
        //     key: memory address (should be word-aligned)
        //     value: word content at address (assumed zero if not present)
        this.memoryMap = {};
    }

    getWord(position) {
        if (BigNumber(position).mod(8) != 0) throw "Position should be word-aligned";
        if (position in this.memoryMap) {
            return this.memoryMap[position];
        }
        return 0;
    }

    setValue(position, value) {
        if (BigNumber(position).mod(8) != 0) throw "Position should be word-aligned";
        if (BigNumber(position).isLessThan(0)) throw "Setting negative value"
        if (BigNumber(position).isGreaterThanOrEqualTo(
            BigNumber(2).pow(64))) throw "Setting value too large"
        this.memoryMap[position] = value;
    }

    // function returns the merkel hash of a sub-interval in memory.
    //   begin - starting address of sub-memory (should be word-aligned)
    //   log2length - the log 2 of the length (in words) of the sub-interval
    // recall that if a key is not present, the value is assumed to be zero.
    subMerkel(memory, begin, log2length) {
        if (!(begin instanceof BigNumber)) throw "Begin should be big number";
        // if begin is not an aligned word, throw
        if (begin.mod(8) != 0) throw "Begin should be word-aligned";
        // if memory is empty, use the iterated hashes of zero bytes
        // console.log(memory, begin, log2length);
        if (isEmpty(memory)) return this.iteratedZeroHashes[log2length];
        // if memory is not empty, but length = 1 return the hash of the word
        if (log2length === 0)
            if (begin in memory) {
                return hashWord(memory[begin]);
            } else {
                return hashWord(0);
            }
        // otherwise split the memory in two pieces and use recursion
        var mem1 = {}
        var mem2 = {}
        // split into two intervals of half the size
        for (var key in memory) {
            if (memory.hasOwnProperty(key)) {
                if (BigNumber(key)
                    .isLessThan(begin.plus(BigNumber(2).pow(log2length + 2)))) {
                    mem1[key] = memory[key];
                } else {
                    mem2[key] = memory[key];
                }
            }
        }
        // returns the hash of the concatenation
        // console.log("split: " + JSON.stringify(mem1)
        //      + " for (" + begin +
        //      ", " + (begin.plus(BigNumber(2).pow(log2length + 2))) + ")"
        //      + " and " + JSON.stringify(mem2)
        //      + " for (" + (begin.plus(BigNumber(2).pow(log2length + 2)))
      //      + ", " + (begin.plus(BigNumber(2).pow(log2length + 3))) + ")");
        return w3.utils.sha3(
            this.subMerkel(mem1, begin, log2length - 1) +
            this.subMerkel(mem2, begin.plus(BigNumber(2).pow(log2length + 2)),
                           log2length - 1).replace(/^0x/, '')
        );
    }

    // returns the proof that a certain position contains a certain word
    // the proof consists of a list with 62 elements:
    //   0          -> hash of the sister word
    //   1 until 60 -> hash of the uncle subtree
    generateProof(position) {
        position = BigNumber(position);
        if (position.mod(8) != 0) throw "Position should be word-aligned";
        if (BigNumber(position).isLessThan(0)) throw "Proving negative position"
        if (BigNumber(position).isGreaterThanOrEqualTo(
            BigNumber(2).pow(64))) throw "Proving position too large"

        //console.log("position " + position);
        var value = this.getWord(position);
        //console.log("value " + value);
        var proof = [];
        for (var i = 0; i < 61; i++) {
            let truncated_deep = position
                .minus(position.mod(BigNumber(2).pow(i + 4)));
            let truncated = position
                .minus(position.mod(BigNumber(2).pow(i + 3)));
            //console.log("truncated three at " + i + ": " + truncated);
            //console.log("truncated four  at " + i + ": " + truncated_deep);
            if (truncated.eq(truncated_deep)) {
                //console.log("submerkel 1: "
                //           + truncated.plus(BigNumber(2).pow(i + 3))
                //           + ", " + BigNumber(2).pow(i + 3))
                proof.push(
                    this.subMerkel(this.memoryMap,
                                   truncated.plus(BigNumber(2).pow(i + 3)), i)
                );
            } else {
                //console.log("submerkel 2: " + truncated
                //           + ", " + BigNumber(2).pow(i + 3))
                proof.push(
                    this.subMerkel(this.memoryMap, truncated_deep, i)
                );
            }
        }
        return proof;
    }

    // verifies a proof that a certain position contains a certain word
    //   we start with the hash of the word at position.
    //   hashing this inductively with the uncle hash
    //   should ultimately return the hash of the whole tree
    verifyProof(position, value, proof) {
        position = BigNumber(position);
        if (position.mod(8) != 0) throw "Position should be word-aligned";
        if (BigNumber(position).isLessThan(0)) throw "Verifying negative position"
        if (BigNumber(position).isGreaterThanOrEqualTo(
            BigNumber(2).pow(64))) throw "Verifying position too large"
        let running_hash = hashWord(value);
        //console.log("hashWord(value): " + running_hash);
        //console.log("proof[0]: " + proof[0]);
      for (var i = 0; i < 61; i++) {
            let truncated_deep = position
                .minus(position.mod(BigNumber(2).pow(i + 4)));
            let truncated = position
                .minus(position.mod(BigNumber(2).pow(i + 3)));
            if (truncated.eq(truncated_deep)) {
                //console.log("case1: " + this.subMerkel(
                //     this.memoryMap,
                //    truncated.plus(BigNumber(2).pow(i + 3)), i))
                running_hash = w3.utils.sha3(
                    running_hash + proof[i].replace(/^0x/, '')
                    //this.subMerkel(this.memoryMap,
                    //               truncated.plus(BigNumber(2).pow(i + 3)), i)
                )
            } else {
                //console.log("case2: " + this.subMerkel(
                //    this.memoryMap, truncated, i))
                running_hash = w3.utils.sha3(
                    //this.subMerkel(this.memoryMap, truncated_deep, i) +
                    proof[i] + running_hash.replace(/^0x/, '')
                )
            }
            // if (i < 4) {
            //   console.log("-----------(");
            //   console.log("i: " + i + ", running_hash: " + running_hash);
            //   console.log("i: " + i + ", subtree merkel" +
            //               this.subMerkel(this.memoryMap, truncated_deep, i + 1));
            //   console.log(")-----------");
            // }
        }
        // console.log("sha  0: " + hashWord(0));
        // console.log("sha  1: " + hashWord(1));
        // let a = (w3.utils.sha3(hashWord(1) + hashWord(0)));
        // let b = (w3.utils.sha3(hashWord(0) + hashWord(0)));
        // console.log("sha 10: " + a);
        // console.log("sha 00: " + b);
        // let c = (w3.utils.sha3(b + a));
        // console.log("sha all " + c);
        // console.log("running_hash: " + running_hash);
        // console.log(proof);
        return (running_hash == this.merkel());
    }


    merkel() { return this.subMerkel(this.memoryMap, BigNumber(0), 61) }
}

module.exports = { MemoryManager: MemoryManager };


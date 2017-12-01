const Web3 = require('web3');

web3 = new Web3();

// returns whether an object is empty
function isEmpty(obj) {
    return Object.keys(obj).length === 0;
}

// convert char to hex
function charToHex(value) {
    var str = value.toString(16);
    if (str.length == 1) return "0x0" + str;
    return "0x" + str;
}

// initialize an array of iterated keccaks of a zero byte
iteratedZeroHashes = [web3.utils.soliditySha3({type: 'uint8', value: 0})];
for (i = 0; i < 64; i++) {
    iteratedZeroHashes.push(web3.utils.sha3(iteratedZeroHashes[i],
                                            iteratedZeroHashes[i]));
}
// console.log(iteratedZeroHashes[64]);

// this fuction receives a hash table memory with some values filled.
// then it returns the merkel hash of the memory from begin to 2^log2length
// note that if key is not present, value is assumed to be zero.
function merkelHash(memory, begin, log2length) {
    // if memory is empty, use the iterated hashes of zero bytes
    //console.log(memory, begin, log2length);
    if (isEmpty(memory)) return iteratedZeroHashes[log2length];
    // if memory is not empty, return the byte at location begin
    if (log2length == 0)
        return web3.utils.soliditySha3({type: 'uint8', value: memory[begin]});
    // otherwise split the memory in two pieces and use recursion
    var mem1 = {}
    var mem2 = {}

    for (var key in memory) {
        if (memory.hasOwnProperty(key)) {
            if (key < begin + Math.pow(2, log2length - 1)) {
                mem1[key] = memory[key];
            } else {
                mem2[key] = memory[key];
            }
        }
    }
    //console.log("split into " + JSON.stringify(mem1) + " for " + begin + ", " + (log2length - 1) +
    //            " and " + JSON.stringify(mem2) + " for " + (begin + Math.pow(2, log2length - 1)) + ", " + (log2length - 1));
    return web3.utils.sha3(merkelHash(mem1, begin, log2length - 1) +
                           merkelHash(mem2, begin + Math.pow(2, log2length - 1),
                                      log2length - 1));
}

class MemoryManager {

    constructor() {
        memoryMap = {};
    }

    getValue(position) {
        if (position in memoryMap) {
            return memoryMap[position];
        }
        return 0;
    }

    setValue(position, value) {
        memoryMap[posiiton] = value;
    }

}

module.exports = { merkelHash: merkelHash };


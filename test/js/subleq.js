const mocha = require('mocha')
const mm = require('../utils/mm.js')
const subleq = require('../utils/subleq.js')
//var Uint64BE = require("int64-buffer").Uint64BE;
const BigNumber = require('bignumber.js');

const chai = require("chai");
chai.config.includeStack = true;
const expect = chai.expect;
const assert = chai.assert;

hd_position = BigNumber("0x0000000000000000");
pc_position = BigNumber("0x4000000000000000");
// input counter
ic_position = BigNumber("0x4000000000000008");
// output counter
oc_position = BigNumber("0x4000000000000010");
// address for halted state
halted_state = BigNumber("0x4000000000000018");
initial_ic = BigNumber("0x8000000000000000");
initial_oc = BigNumber("0xc000000000000000");

echo_binary = [-1, 21, 3,
               21, -1, 6,
               21, 22, 9,
               22, 23, -1,
               21, 21, 15,
               22, 22, 18,
               23, 23, 0,
               0, 0, 0]

input_string = [2, 4, 8, 16, 32, 64, -1];

function two_complement_32(decimal) {
  if (decimal >= 0) {
    return "0x" + ("000000000000000" + decimal.toString(16)).substr(-16);
  }
  low_bits = (decimal < 0 ? (0xFFFFFFFF + decimal + 1) : decimal).toString(16);
  return "0xffffffff" + low_bits;
};

describe('Testing memory manager', function() {
  it('Basic tests', function() {
    let myMM = new mm.MemoryManager();
    let mySubleq = new subleq.Subleq(myMM);

    // write program to memory contract
    var softwareLength = echo_binary.length;
    for (let i = 0; i < softwareLength; i++) {
      myMM.setValue(8 * i, two_complement_32(echo_binary[i]));
    }
    // write ic position
    myMM.setValue(ic_position, initial_ic);
    expect(myMM.getWord(ic_position)).to.equal(initial_ic);

    // write oc position
    myMM.setValue(oc_position, initial_oc);
    // write input in memory contract
    var inputLength = input_string.length;
    for (let i = 0; i < inputLength; i++) {
      myMM.setValue(BigNumber(initial_ic).plus(8 * i),
                    two_complement_32(input_string[i]));
      expect(myMM.getWord(BigNumber(initial_ic).plus(8 * i)))
        .to.equal(two_complement_32(input_string[i]));
    }

    mySubleq.run(300);

    let j = 0;
    let response;
    // verifying output
    while (true) {
      response = myMM.getWord(BigNumber(initial_oc).plus(8 * j));
      expect(response).to.equal(two_complement_32(input_string[j]));
      if (response == '0xffffffffffffffff') break;
      j++;
    }
  });
});




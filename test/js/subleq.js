const BigNumber = require('bignumber.js');
const expect = require("chai").expect;

const mm = require('../../utils/mm.js')
const subleq = require('../../utils/subleq.js')
const twoComplement32 = require('../../utils/tools.js').twoComplement32;

echo_binary = [-1, 21, 3,
               21, -1, 6,
               21, 22, 9,
               22, 23, -1,
               21, 21, 15,
               22, 22, 18,
               23, 23, 0,
               0, 0, 0]

input_string = [2, 4, 8, 16, 32, 64, -1];

describe('Testing subleq', function() {
  it('Basic tests', function() {
    let hd_position = BigNumber("0x0000000000000000");
    let pc_position = BigNumber("0x4000000000000000");
    // input counter
    let ic_position = BigNumber("0x4000000000000008");
    // output counter
    let oc_position = BigNumber("0x4000000000000010");
    // address for halted state
    let halted_state = BigNumber("0x4000000000000018");
    let initial_ic = BigNumber("0x8000000000000000");
    let initial_oc = BigNumber("0xc000000000000000");


    let myMM = new mm.MemoryManager();
    let mySubleq = new subleq.Subleq(myMM);

    // write program to memory contract
    var softwareLength = echo_binary.length;
    for (let i = 0; i < softwareLength; i++) {
      myMM.setValue(8 * i, twoComplement32(echo_binary[i]));
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
                    twoComplement32(input_string[i]));
      expect(myMM.getWord(BigNumber(initial_ic).plus(8 * i)))
        .to.equal(twoComplement32(input_string[i]));
    }

    mySubleq.run(300);

    let j = 0;
    let response;
    // verifying output
    while (true) {
      response = myMM.getWord(BigNumber(initial_oc).plus(8 * j).toString());
      expect(response).to.equal(twoComplement32(input_string[j]));
      if (response == '0xffffffffffffffff') break;
      j++;
    }
  });
});





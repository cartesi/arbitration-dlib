const BigNumber = require('bignumber.js');
const expect = require("chai").expect;

const mm = require('../../utils/mm.js')
const subleq = require('../../utils/subleq.js')
const twoComplement32 = require('../../utils/tools.js').twoComplement32;

describe('Testing subleq', function() {
  let echo_binary = [-1, 21, 3,
                     21, -1, 6,
                     21, 22, 9,
                     22, 23, -1,
                     21, 21, 15,
                     22, 22, 18,
                     23, 23, 0,
                     0, 0, 0];

  let input_string = [2, 4, 8, 16, 32, 64, -1];

  it('Basic tests', function() {
    let hd_position = "0x0000000000000000";
    let pc_position = "0x4000000000000000";
    let ic_position = "0x4000000000000008"; // where to read input counter
    let oc_position = "0x4000000000000010"; // where to read output counter
    let halted_state = "0x4000000000000018"; // address for halted state
    let rSizePosition = "0x4000000000000020";
    let iSizePosition = "0x4000000000000028";
    let oSizePosition = "0x4000000000000030";
    let initial_ic = "0x8000000000000000"; // input counter
    let initial_oc = "0xc000000000000000"; // output counter

    let myMM = new mm.MemoryManager();
    let mySubleq = new subleq.Subleq(myMM);

    // write program to memory contract
    var softwareLength = echo_binary.length;
    for (let i = 0; i < softwareLength; i++) {
      myMM.setWord(8 * i, twoComplement32(echo_binary[i]));
      expect(myMM.getWord(8 * i)).to.equal(twoComplement32(echo_binary[i]));
    }

    // write ic position
    myMM.setWord(ic_position, initial_ic);
    expect(myMM.getWord(ic_position)).to.equal(initial_ic);

    // write oc position
    myMM.setWord(oc_position, initial_oc);
    // write rSize
    myMM.setWord(rSizePosition, 100000)
    // write iSize
    myMM.setWord(iSizePosition, 100000)
    // write oSize
    myMM.setWord(oSizePosition, 100000)
    // write input in memory contract
    var inputLength = input_string.length;
    for (let i = 0; i < inputLength; i++) {
      myMM.setWord(BigNumber(initial_ic).plus(8 * i),
                    twoComplement32(input_string[i]));
      expect(myMM.getWord(BigNumber(initial_ic).plus(8 * i)))
        .to.equal(twoComplement32(input_string[i]));
    }

    mySubleq.run(300);

    let j = 0;
    let response;
    // verifying output
    while (true) {
      // console.log(initial_oc);
      // console.log(initial_oc.plus(8 * j));
      // console.log(initial_oc.plus(8 * j).toString());
      // console.log(myMM.getWord(initial_oc.plus(8 * j).toString()));
      response = myMM.getWord(BigNumber(initial_oc).plus(8 * j).toString());
      expect(response).to.equal(twoComplement32(input_string[j]));
      if (response == '0xffffffffffffffff') break;
      j++;
    }
  });
});

var BigNumber = require('bignumber.js');

pcPosition = BigNumber("0x4000000000000000");
icPosition = BigNumber("0x4000000000000008");
ocPosition = BigNumber("0x4000000000000010");
haltedState = BigNumber("0x4000000000000018");

function pad(n, width, z) {
  z = z || '0';
  n = n + '';
  return n.length >= width ? n : new Array(width - n.length + 1).join(z) + n;
}

function two_complement_32(decimal) {
  if (decimal >= 0) {
    return "0x" + ("000000000000000" + decimal.toString(16)).substr(-16);
  }
  low_bits = (decimal < 0 ? (0xFFFFFFFF + decimal + 1) : decimal).toString(16);
  return "0xffffffff" + low_bits;
};

function two_complement_32_inverse(hexa) {
  hexa = pad(BigNumber(hexa).toString(16), 16);
  if (hexa.startsWith("0x00000000") || hexa.startsWith("00000000")) {
    return parseInt(hexa, 16);
  }
  if (hexa.startsWith("0xffffffff") || hexa.startsWith("ffffffff")) {
    a = parseInt(hexa.substr(hexa.length - 8), 16);
    return -(~a + 1);
  }
  throw "Not 32 bits conversion";
}

const ramSize = 100000;
const inputMaxSize = 100000;
const outputMaxSize = 100000;

class Subleq {

  constructor(mm) {
    this.mm = mm;
  }

  // Architecture
  // +----------------+----------------+----------------+----------------+
  // | ram            | pc ic oc       | input          | output         |
  // +----------------+----------------+----------------+----------------+
  // Exit codes:
  // 0  - Success
  // 1  - Halted machine
  // 2  - Operator A should be -1, 0 or positive
  // 3  - Operator B should be -1, 0 or positive
  // 4  - Operators A and B cannot be both -1
  // 5  - Out of memory (addressed by operator A)
  // 6  - Out of memory (addressed by operator B)
  // 7  - Out of memory (addressed by operator C)
  // 8  - Overflow of maximum input size
  // 9  - Overflow of maximum output size
  // 10 -
  // 11 -
  // 12 -
  // 13 -

  step() {
    let pc = this.mm.getWord(pcPosition);
    let ic = this.mm.getWord(icPosition);
    let oc = this.mm.getWord(ocPosition);
    let hs = this.mm.getWord(haltedState);
    let memAddrA = two_complement_32_inverse(this.mm.getWord(pc));
    let memAddrB = two_complement_32_inverse(this.mm.getWord(
      BigNumber(pc).add(8)));
    let memAddrC = two_complement_32_inverse(this.mm.getWord(
      BigNumber(pc).add(16)));

    // if first or second operator are < -1, throw
    if (hs != 0x0000000000000000) { return 1; }
    if (memAddrA < -1) { return 2; }
    if (memAddrB < -1) { return 3; }
    if (memAddrA == -1 && memAddrB == -1) { return 4; }
    if (memAddrA >= 0 && memAddrA > ramSize)
       { return 5; }
    if (memAddrB >= 0 && memAddrB > ramSize)
       { return 6; }
    // if first operator is -1, read from input
    if (memAddrA == -1) {
      // read input at ic
      let loaded = this.mm.getWord(ic);
      this.mm.setValue(memAddrB * 8, loaded);
      if (BigNumber(ic).minus("0x8000000000000000") > inputMaxSize) {
        return 8;
      }
      // increment ic;
      this.mm.setValue(icPosition, BigNumber(ic).plus(8));
      // increment pc by three words
      this.mm.setValue(pcPosition, BigNumber(pc).plus(24));
      return 0;
    }
    // if valueA is non-negative, load the memory address
    let valueA = this.mm.getWord(memAddrA * 8);
    // if first operator is positive but second operator is -1, write output
    if (memAddrB == -1) {
      // write contents addressed by first operator into output
      this.mm.setValue(oc, valueA);
      if (BigNumber(oc).minus("0xc000000000000000") > outputMaxSize) {
        return 9;
      }
      // increment oc
      this.mm.setValue(ocPosition, BigNumber(oc).plus(8));
      // increment pc by three words
      this.mm.setValue(pcPosition, BigNumber(pc).plus(24));
      if (two_complement_32_inverse(valueA) < 0) { return 1; }
      return 0;
    }
    // if valueB is non-negative, make the subleq operation
    let valueB = this.mm.getWord(memAddrB * 8);
    let subtraction = (two_complement_32_inverse(valueB)
                   - two_complement_32_inverse(valueA));
    // write subtraction to memory addressed by second operator
    this.mm.setValue(memAddrB * 8, subtraction);
    if (subtraction <= 0) {
      if (memAddrC < 0) {
        // halt machine
        this.mm.setValue(haltedState, 1);
        return 0;
      }
      if (memAddrC > ramSize)
        { return 7; }
      this.mm.setValue(pcPosition, memAddrC * 8);
      return 0;
    }
  }

  run(maxTime) {
    var a;
    for(var i = 0; i < maxTime; i++) {
      a = this.step();
      if (a != 0) break;
    }
  }
}


module.exports.Subleq = Subleq;
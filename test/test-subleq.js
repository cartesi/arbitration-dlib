const fs = require('fs');
const solc = require('solc');
const Web3 = require('web3');
const TestRPC = require("ethereumjs-testrpc");
const mocha = require('mocha')
const coMocha = require('co-mocha')
const mm = require('../utils/mm.js')
const BigNumber = require('bignumber.js');

expect = require('chai').expect;

coMocha(mocha)

aliceKey = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d'
machineKey = '0x6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1'

aliceAddr = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
machineAddr = '0xffcf8fdee72ac11b5c542428b35eef5769c409f0'

echo_binary = [-1, 9, -1,
               9, -1, 6,
               9, 9, 0,
               0]

input_string = [2, 4, 8, 16, 32, 64, -1];

function two_complement_32(decimal) {
  if (decimal >= 0) {
    return "0x" + ("000000000000000" + decimal.toString(16)).substr(-16);
  }
  low_bits = (decimal < 0 ? (0xFFFFFFFF + decimal + 1) : decimal).toString(16);
  return "0xffffffff" + low_bits;
};

hd_position =     ("0x0000000000000000");
pc_position =     ("0x4000000000000000");
// input counter
ic_position =     ("0x4000000000000008");
// output counter
oc_position =     ("0x4000000000000010");
// address for halted state
halted_state =    ("0x4000000000000018");
initial_ic =      ("0x8000000000000000");
initial_oc =      ("0xc000000000000000");

var testrpcParameters = {
  "accounts":
  [   { "balance": 100000000000000000000,
        "secretKey": aliceKey },
      { "balance": 100000000000000000000,
        "secretKey": machineKey }
  ]
}

web3 = new Web3(TestRPC.provider(testrpcParameters));

// compile testMemory contract
const contractSource = fs.readFileSync('src/testMemory.sol').toString();
const compiledContract = solc.compile(contractSource, 1);
expect(compiledContract.errors, compiledContract.errors).to.be.undefined;
const bytecode = compiledContract.contracts[':testMemory'].bytecode;
const abi = JSON.parse(compiledContract.contracts[':testMemory'].interface);
// create contract object
testMemoryContract = new web3.eth.Contract(abi);

// compile subleq contract
const contractSource_2 = fs.readFileSync('src/subleq.sol').toString();
const compiledContract_2 = solc.compile(contractSource_2, 1);
expect(compiledContract_2.errors, compiledContract_2.errors).to.be.undefined;
const bytecode_2 = compiledContract_2.contracts[':subleq'].bytecode;
const abi_2 = JSON.parse(compiledContract_2.contracts[':subleq'].interface);
// create contract object
subleqContract = new web3.eth.Contract(abi_2);

function hashWord(word) {
    return web3.utils.soliditySha3({type: 'uint64', value: word});
}

describe('Testing memory manager contract', function() {
  it('Checking functionalities', function*() {
    this.timeout(150000)

    // deploy testMemory contract and update object
    testMemoryContract = yield testMemoryContract.deploy({
      data: bytecode,
      arguments: []
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // this line should leave after they fix this bug
    // https://github.com/ethereum/web3.js/issues/1266
    testMemoryContract.setProvider(web3.currentProvider)

    // check if waiting to write values
    currentState = yield testMemoryContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('0');

    // write program to memory contract
    console.log('write program to memory contract');
    var softwareLength = echo_binary.length;
    for (let i = 0; i < softwareLength; i++) {
      // write on memory
      console.log(two_complement_32(echo_binary[i]));
      response = yield testMemoryContract.methods
        .write(8 * i, two_complement_32(echo_binary[i]))
        .send({ from: aliceAddr, gas: 1500000 })
        .on('receipt');
    }

    // write ic position
    response = yield testMemoryContract.methods
      .write(ic_position, initial_ic)
      .send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // write oc position
    response = yield testMemoryContract.methods
      .write(oc_position, initial_oc)
      .send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // write input in memory contract
    console.log('write input in memory contract');
    var inputLength = input_string.length;
    for (let i = 0; i < inputLength; i++) {
      // write on memory
      console.log(two_complement_32(input_string[i]));
      response = yield testMemoryContract.methods
        .write(BigNumber(initial_ic).plus(8 * i),
               two_complement_32(input_string[i]))
        .send({ from: aliceAddr, gas: 1500000 })
        .on('receipt');
    }

    // finishing writing
    response = yield testMemoryContract.methods
      .finishWritePhase()
      .send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // deploy subleq contract and update object
    subleqContract = yield subleqContract.deploy({
      data: bytecode_2,
      arguments: [testMemoryContract.options.address,
                  1000000, 1000000, 1000000]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    // this line should leave after they fix this bug
    // https://github.com/ethereum/web3.js/issues/1266
    subleqContract.setProvider(web3.currentProvider)

    // check if waiting to read values
    currentState = yield testMemoryContract.methods
      .currentState().call({ from: aliceAddr });
    expect(currentState).to.equal('1');

    let running = '0';

    while (running === '0') {
      // print machine state for debugging
      // response = yield testMemoryContract.methods
      //   .read(pc_position)
      //   .call({ from: aliceAddr, gas: 1500000 });
      // console.log("pc = " + response);
      // for (let j = 0; j < 10; j++) {
      //   response = yield testMemoryContract.methods
      //     .read(8 * j)
      //     .call({ from: aliceAddr, gas: 1500000 });
      //   console.log("hd at: " + j + " = " + response);
      // }
      // for (let j = 0; j < 10; j++) {
      //   response = yield testMemoryContract.methods
      //     .read(BigNumber(initial_ic).add(8 * j))
      //     .call({ from: aliceAddr, gas: 1500000 });
      //   console.log("input at: " + j + " = " + response);
      // }
      // for (let j = 0; j < 10; j++) {
      //   response = yield testMemoryContract.methods
      //     .read(BigNumber(initial_oc).add(8 * j))
      //     .call({ from: aliceAddr, gas: 1500000 });
      //   console.log("output at: " + j + " = " + response);
      // }
      response = yield subleqContract.methods
        .step()
        .send({ from: aliceAddr, gas: 1500000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.StepGiven).not.to.be.undefined;
        });
      running = response.events.StepGiven.returnValues.exitCode;
      console.log(running);
    }

    let j = 0;
    // verifying output
    while (true) {
      response = yield testMemoryContract.methods
        .read(BigNumber(initial_oc).plus(8 * j))
        .call({ from: aliceAddr, gas: 1500000 });
      console.log(response);
      expect(response).to.equal(two_complement_32(input_string[j]));
      if (response == '0xffffffffffffffff') break;
      j++;
    }
    // kill contracts
    response = yield testMemoryContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
    response = yield subleqContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
  });
});

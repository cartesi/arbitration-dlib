const fs = require('fs');
const solc = require('solc');
const Web3 = require('web3');
const TestRPC = require("ethereumjs-testrpc");
const mocha = require('mocha')
const coMocha = require('co-mocha')

expect = require('chai').expect;

coMocha(mocha)

aliceKey = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d'
bobKey = '0x6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1'
eveKey = '0x80bf04d3e10530fca6db5bb15d29c2561b86116f4c03d620036bb74378f802c0'

aliceAddr = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
bobAddr = '0xffcf8fdee72ac11b5c542428b35eef5769c409f0'
eveAddr = '0xd38b636cf8fe793483141c9fa7a572c1f8b3778e'

// compile contract
//const contractSource = fs.readFileSync('src/hireCPU.sol').toString();

var input = {
  'src/hireCPU.sol': fs.readFileSync('src/hireCPU.sol', 'utf8'),
  'src/partition.sol': fs.readFileSync('src/partition.sol', 'utf8'),
  'src/mm.sol': fs.readFileSync('src/mm.sol', 'utf8'),
  'src/lib/bokkypoobah/Token.sol':
  fs.readFileSync('src/lib/bokkypoobah/Token.sol', 'utf8'),
};

// using solc package for node
const compiledContract = solc.compile({ sources: input }, 1);
expect(compiledContract.errors, compiledContract.errors).to.be.undefined;
const tokenBytecode = compiledContract
      .contracts['src/lib/bokkypoobah/Token.sol:Token'].bytecode;
const tokenAbi = JSON.parse(
  compiledContract.contracts['src/lib/bokkypoobah/Token.sol:Token'].interface);

const hireBytecode = compiledContract.contracts['src/hireCPU.sol:hireCPU'].bytecode;
const hireAbi = JSON.parse(compiledContract.contracts['src/hireCPU.sol:hireCPU'].interface);


// testrpc
var testrpcParameters = {
  "accounts":
  [   { "balance": 100000000000000000000,
        "secretKey": aliceKey },
      { "balance": 100000000000000000000,
        "secretKey": bobKey },
      { "balance": 100000000000000000000,
        "secretKey": eveKey }
  ]
}
web3 = new Web3(TestRPC.provider(testrpcParameters));

// promisify jsonRPC direct call
sendRPC = function(param){
  return new Promise(function(resolve, reject){
    web3.currentProvider.sendAsync(param, function(err, data){
      if(err !== null) return reject(err);
      resolve(data);
    });
  });
}

// create contract object
tokenContract = new web3.eth.Contract(tokenAbi);

// another option is using a node serving in port 8545 with those users
// web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));


describe('Testing partition contract', function() {
  beforeEach(function() {
    this.timeout(15000);

  });

  it('Find divergence', function*() {
    this.timeout(15000)

    // deploy contract and update object
    tokenContract = yield tokenContract.deploy({
      data: tokenBytecode,
      arguments: []
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    console.log(tokenContract.options.address);
    expect(tokenContract.options.address).to
      .equal('0xe78A0F7E598Cc8b0Bb87894B0F60dD2a88d6a8Ab');
    process.exit(1);

    // create contract object
    hireContract = new web3.eth.Contract(abi);

    // another option is using a node serving in port 8545 with those users
    // web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

    // deploy contract and update object
    hireContract = yield hireContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, bobAddr, initialHash, bobFinalHash,
                  finalTime, querySize, roundDuration]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

  });
});




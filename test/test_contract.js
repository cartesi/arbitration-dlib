const fs = require('fs');
const solc = require('solc');
const mocha = require('mocha')
const Web3 = require('web3');
const coMocha = require('co-mocha')

expect = require('chai').expect;

coMocha(mocha)

var TestRPC = require("ethereumjs-testrpc");

aliceKey = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d'
aliceAddr = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'

describe('Testing basic contract deployment', function() {
  beforeEach(function() {
      //testrpc parameters
      var testrpcParameters = {
          "accounts":
          [   { "balance": 100000000000000000000,
                "secretKey": aliceKey }
          ],
          //"debug": true
      }

      web3 = new Web3(TestRPC.provider(testrpcParameters));
      //web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
  });

  it('Deploy and interact with contract', function*() {
      this.timeout(10000)

      // get alice account and balance
      accountList = yield web3.eth.getAccounts()
      accountList = accountList.map(function(x){ return x.toLowerCase() })
      expect(accountList).to.include(aliceAddr, 'Alice not there');
      aliceBalance = yield web3.eth.getBalance(aliceAddr)
      expect(aliceBalance).to.equal(web3.utils.toWei(100), 'Wrong balance for Alice');

      // compile contract
      const contractSource = fs.readFileSync('src/partition.sol').toString();
      const compiledContract = solc.compile(contractSource, 1);
      expect(compiledContract.errors, compiledContract.errors).to.be.undefined;
      const bytecode = compiledContract.contracts[':partition'].bytecode;
      const abi = JSON.parse(compiledContract.contracts[':partition'].interface);

      // deploy contract with parameter 'Hello!'
      greeterContract = new web3.eth.Contract(abi);
      encodedABI = greeterContract.deploy({
          data: bytecode,
          arguments: ['Hello!']
      }).encodeABI()
      receipt = yield web3.eth.sendTransaction({
          from: aliceAddr,
          data: encodedABI,
          gas: 1500000
      });
      greeterContract.options.address = receipt.contractAddress;

      // This alternative method gives you the receipt in an event
      // greeterContract = yield greeterContract.deploy({
      //     data: bytecode,
      //     arguments: ['Hello!']
      // }).send({
      //     from: aliceAddr,
      //     gas: 1500000
      // }).on('receipt', console.log);

      // check contract owner (every public variable has getter method)
      response = yield greeterContract.methods.owner().call({
          from: aliceAddr,
      });
      expect(response.toLowerCase()).to.equal(aliceAddr);

      // check ballance after transaction
      gasPrice = yield web3.eth.getGasPrice();
      aliceBalance = yield web3.eth.getBalance(aliceAddr)
      expect(+aliceBalance + receipt.gasUsed * gasPrice)
          .to.equal(+web3.utils.toWei(100), 'Wrong remaining balance for Alice');

      // check original greeting with call (no transaction)
      originalGreeting = yield greeterContract.methods.greet().call({
          from: aliceAddr,
      });
      expect(originalGreeting).to.equal('Hello!', 'Original greeting does not match.');

      // change greeting with send
      response = yield greeterContract.methods.change('Hi there!')
          .send({
              from: aliceAddr,
              gas: 1500000
          });
      returnValues = response.events.ChangeGreetingEvent.returnValues;
      expect(returnValues.oldGreeting).to.equal('Hello!', 'Wrong old greeting');
      expect(returnValues.newGreeting).to.equal('Hi there!', 'Wrong new greeting');

      // check original greeting (with call)
      originalGreeting = yield greeterContract.methods.greet().call({
          from: aliceAddr,
      });
      expect(originalGreeting)
          .to.equal('Hi there!', 'Original greeting does not match.');

      // kill contract
      response = yield greeterContract.methods.kill()
          .send({
              from: aliceAddr,
              gas: 1500000
          });
  });
});




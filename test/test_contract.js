const fs = require('fs');
const solc = require('solc');
const mocha = require('mocha')
const Web3 = require('web3');
const coMocha = require('co-mocha')

expect = require('chai').expect;

coMocha(mocha)

var TestRPC = require("ethereumjs-testrpc");

aliceKey = '0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d'
bobKey = '0x6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1'

aliceAddr = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
bobAddr = '0xffcf8fdee72ac11b5c542428b35eef5769c409f0'

// compile contract
const contractSource = fs.readFileSync('src/partition.sol').toString();
const compiledContract = solc.compile(contractSource, 1);
expect(compiledContract.errors, compiledContract.errors).to.be.undefined;
const bytecode = compiledContract.contracts[':partition'].bytecode;
const abi = JSON.parse(compiledContract.contracts[':partition'].interface);

describe('Testing partition contract', function() {
  beforeEach(function() {
      //testrpc parameters
      var testrpcParameters = {
          "accounts":
          [   { "balance": 100000000000000000000,
                "secretKey": aliceKey },
              { "balance": 100000000000000000000,
                "secretKey": bobKey }
          ],
          //"debug": true
      }

      web3 = new Web3(TestRPC.provider(testrpcParameters));
      //web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
  });

  it('Verify mistake from Bob', function*() {
      this.timeout(10000)

      console.log('aaa')

      // prepare contest
      initialHash = web3.utils.sha3('start');
      aliceFinalHash = initialHash;
      bobFinalHash = initialHash;

      aliceHistory = [];
      bobHistory = [];

      finalTime = 2000
      lastAggreement = Math.floor((Math.random() * 2000 - 1) + 1); ;

      for (i = 0; i <= 2000; i++) {
          aliceHistory.push(aliceFinalHash);
          bobHistory.push(bobFinalHash);
          aliceFinalHash = web3.utils.sha3(aliceFinalHash);
          bobFinalHash = web3.utils.sha3(bobFinalHash);
          // introduce bob mistake
          if (i == lastAggreement + 1)
            { bobFinalHash = web3.utils.sha3('mistake'); }
      }
      console.log('aaa')
      // deploy contract for challenge
      partitionContract = new web3.eth.Contract(abi);

      // This alternative method gives you the receipt in an event
      partitionContract = yield partitionContract.deploy({
          data: bytecode,
          arguments: [aliceAddr, bobAddr, initialHash, bobFinalHash,
                      finalTime, 4, 10, 3600]
      }).send({
          from: aliceAddr,
          gas: 1500000
      }).on('receipt');
      console.log('aaa')
      // check contract owner (every public variable has getter method)
      response = yield partitionContract.methods.owner().call({
          from: aliceAddr,
      });
      expect(response.toLowerCase()).to.equal(aliceAddr);

      while (true) {
          currentState = yield partitionContract.methods
              .currentState().call({ from: aliceAddr });
          console.log(currentState);
          expect(currentState).to.equal('0');


      }


      // check original greeting with call (no transaction)
      originalGreeting = yield partitionContract.methods.greet().call({
          from: aliceAddr,
      });
      expect(originalGreeting).to.equal('Hello!', 'Original greeting does not match.');

      // change greeting with send
      response = yield partitionContract.methods.change('Hi there!')
          .send({
              from: aliceAddr,
              gas: 1500000
          });
      returnValues = response.events.ChangeGreetingEvent.returnValues;
      expect(returnValues.oldGreeting).to.equal('Hello!', 'Wrong old greeting');
      expect(returnValues.newGreeting).to.equal('Hi there!', 'Wrong new greeting');

      // check original greeting (with call)
      originalGreeting = yield partitionContract.methods.greet().call({
          from: aliceAddr,
      });
      expect(originalGreeting)
          .to.equal('Hi there!', 'Original greeting does not match.');

      // kill contract
      response = yield partitionContract.methods.kill()
          .send({
              from: aliceAddr,
              gas: 1500000
          });
  });
});




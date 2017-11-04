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

// using solc package for node
const compiledContract = solc.compile(contractSource, 1);
expect(compiledContract.errors, compiledContract.errors).to.be.undefined;
const bytecode = compiledContract.contracts[':partition'].bytecode;
const abi = JSON.parse(compiledContract.contracts[':partition'].interface);

// using solc from the command line
// const { exec } = require('child_process');
// exec('/home/cortex/solidity/build/solc/solc -o /home/cortex/project/contracts --abi --bin /home/cortex/contracts/src/partition.sol', (err, stdout, stderr) => {
//     if (err) { console.log('Error compiling contract'); return; }
//     console.log(`stdout: ${stdout}`);
//     console.log(`stderr: ${stderr}`);
// });
// const bytecode = fs.readFileSync('src/partition.bin').toString();
// const abi = JSON.parse(fs.readFileSync('src/partition.abi').toString());

describe('Testing partition contract', function() {
  beforeEach(function() {
    // testrpc
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

    // another option is using a node serving in port 8545 with those users
    // web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
  });

  it('Find divergence', function*() {
    this.timeout(15000)

    // prepare contest
    initialHash = web3.utils.sha3('start');
    aliceFinalHash = initialHash;
    bobFinalHash = initialHash;

    aliceHistory = [];
    bobHistory = [];

    finalTime = 50000;
    querySize = 7;
    maxNumberQueries = 30;
    roundDuration = 3600;
    lastAggreement = Math.floor((Math.random() * finalTime - 1) + 1);

    for (i = 0; i <= finalTime; i++) {
      aliceHistory.push(aliceFinalHash);
      bobHistory.push(bobFinalHash);
      aliceFinalHash = web3.utils.sha3(aliceFinalHash);
      bobFinalHash = web3.utils.sha3(bobFinalHash);
      // introduce bob mistake
      if (i == lastAggreement)
      { bobFinalHash = web3.utils.sha3('mistake'); }
    }
    // create contract object
    partitionContract = new web3.eth.Contract(abi);

    // deploy contract and update object
    partitionContract = yield partitionContract.deploy({
      data: bytecode,
      arguments: [aliceAddr, bobAddr, initialHash, bobFinalHash,
                  finalTime, querySize, maxNumberQueries, roundDuration]
    }).send({ from: aliceAddr, gas: 1500000 })
      .on('receipt');

    queryArray = [];
    replyArray = [];
    for (i = 0; i < querySize; i++) queryArray.push(0);
    for (i = 0; i < querySize; i++) replyArray.push("");

    while (true) {
      var i;
      // check if the state is waiting hashes
      currentState = yield partitionContract.methods
        .currentState().call({ from: bobAddr });
      expect(currentState).to.equal('1');

      // get the query array and prepare response
      // solidity cannot return dynamic array from function
      for (i = 0; i < querySize; i++) {
        queryArray[i] = yield partitionContract.methods
          .queryArray(i).call({ from: bobAddr });
        replyArray[i] = bobHistory[queryArray[i]];
      }
      //console.log(queryArray);

      // sending hashes from alice should fail
      response = yield partitionContract.methods
        .replyQuery(queryArray, replyArray)
        .send({ from: aliceAddr, gas: 1500000 })
        .catch(function(error) {
          expect(error.message).to.have.string('VM Exception');
        });

      // alice claiming victory should fail
      response = yield partitionContract.methods
        .claimVictoryByTime()
        .send({ from: aliceAddr, gas: 1500000 })
        .catch(function(error) {
          expect(error.message).to.have.string('VM Exception');
        });

      // send hashes
      response = yield partitionContract.methods
        .replyQuery(queryArray, replyArray)
        .send({ from: bobAddr, gas: 1500000 })
        .on('receipt', function(receipt) {
          expect(receipt.events.HashesPosted).not.to.be.undefined;
        });

      returnValues = response.events.HashesPosted.returnValues;

      // find first last time of query where there was aggreement
      var lastConsensualQuery = 0;
      for (i = 0; i < querySize - 1; i++){
        if (aliceHistory[returnValues.thePostedTimes[i]]
            == returnValues.thePostedHashes[i]) {
          lastConsensualQuery = i;
        } else {
          break;
        }
      }

      // check if the state is waiting query
      currentState = yield partitionContract.methods
        .currentState().call({ from: bobAddr });
      expect(currentState).to.equal('0');

      // bob claiming victory should fail
      response = yield partitionContract.methods
        .claimVictoryByTime()
        .send({ from: bobAddr, gas: 1500000 })
        .catch(function(error) {
          expect(error.message).to.have.string('VM Exception');
        });

      leftPoint = returnValues.thePostedTimes[lastConsensualQuery];
      rightPoint = returnValues.thePostedTimes[lastConsensualQuery + 1];

      // check if the interval is unitary
      if (+rightPoint == +leftPoint + 1) {
        // if the interval is unitary, present divergence
        response = yield partitionContract.methods
          .presentDivergence(leftPoint)
          .send({ from: aliceAddr, gas: 1500000 })
          .on('receipt', function(receipt) {
            expect(receipt.events.DivergenceFound).not.to.be.undefined;
          });
        returnValues = response.events.DivergenceFound.returnValues;
        expect(+returnValues.timeOfDivergence).to.equal(lastAggreement);
        break;
      } else {
        // send query with last queried time of aggreement
        response = yield partitionContract.methods
          .makeQuery(lastConsensualQuery, leftPoint, rightPoint)
          .send({ from: aliceAddr, gas: 1500000 })
          .on('receipt', function(receipt) {
            expect(receipt.events.QueryPosted).not.to.be.undefined;
          });
      }
    }

    // kill contract
    response = yield partitionContract.methods.kill()
      .send({ from: aliceAddr, gas: 1500000 });
  });
});




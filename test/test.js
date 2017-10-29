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

describe('Basic TestRPC test', function() {
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

  it('Transfer 7 ether from Alice to Bob', function*() {
      accountList = yield web3.eth.getAccounts()
      accountList = accountList.map(function(x){ return x.toLowerCase() })
      expect(accountList).to.include(aliceAddr, 'Alice not there');
      expect(accountList).to.include(bobAddr, 'Bob not there');
      //queriedAliceAddr = yield web3.eth.getCoinbase()
      //expect(queriedAliceAddr.toLowerCase())
      //    .to.equal(aliceAddr, 'Alice is not coin base');
      aliceBalance = yield web3.eth.getBalance(aliceAddr)
      bobBalance = yield web3.eth.getBalance(bobAddr)
      expect(aliceBalance).to.equal(web3.utils.toWei(100), 'Wrong balance for Alice');
      expect(bobBalance).to.equal(web3.utils.toWei(100), 'Wrong balance for Bob');
      // Transfer 1000000 wei from Alice to Bob
      gasPrice = yield web3.eth.getGasPrice();
      transactionCallback = yield web3.eth.sendTransaction({
          from: aliceAddr,
          to: bobAddr,
          gas: 1500000,
          value: web3.utils.toWei(7)
      })
      aliceBalance = yield web3.eth.getBalance(aliceAddr)
      bobBalance = yield web3.eth.getBalance(bobAddr)
      // The unary operator + converts a string to number
      expect(+aliceBalance + transactionCallback.gasUsed * gasPrice + +web3.utils.toWei(7))
          .to.equal(+web3.utils.toWei(100), 'Wrong remaining balance for Alice');
      expect(bobBalance).to.equal(web3.utils.toWei(107), 'Wrong balance for Bob')
  });

  //    var code = "603d80600c6000396000f3007c01000000000000000000000000000000000000000000000000000000006000350463c6888fa18114602d57005b6007600435028060005260206000f3";
  //    // Create contract
  //    transactionCallback = yield web3.eth.sendTransaction({
  //        from: aliceAddr,
  //        gas: 1500000,
  //        data: '0x' + code
  //    })


  //  it('Load and compile contract'); a = function*() {
  //    this.timeout(10000)
  //    const contractSource = fs.readFileSync('contracts/greeter.sol').toString();
  //    const compiledContract = solc.compile(contractSource, 1);
  //    const bytecode = compiledContract.contracts[':greeter'].bytecode;
  //    const abi = JSON.parse(compiledContract.contracts[':greeter'].interface);
  //    a = '0x60';
  //    console.log(aliceAddr);
  //    // Contract object
  //    const greeterContract = new web3.eth.Contract(abi);
  //    //console.log(greeterContract)
  //    deployedContract = yield greeterContract.deploy({
  //        data: a,
  //        arguments: ['Hello!']
  //    }).send({
  //        from: aliceAddr,
  //        gas: 1500000,
  //        gasPrice: '30000000000000'
  //    }, function(error, transactionHash){  })
  //        .on('error', function(error){ console.log("AAA" + error) })
  //        .on('transactionHash', function(transactionHash){ console.log("BBB" + transactionHash) })
  //        .on('receipt', function(receipt){
  //            console.log(receipt.contractAddress) // contains the new contract address
  //        })
  //        .on('confirmation', function(confirmationNumber, receipt){ console.log(confirmationNumber) })
  //        .then(function(newContractInstance){
  //            console.log(newContractInstance.options.address) // instance with the new contract address
  //        });}



  //});
});




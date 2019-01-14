#!/usr/bin/node

const Web3 = require('web3');
const fs = require('fs');
var web3 = new Web3('http://127.0.0.1:8545');

const sendRPC = function(web3, param){
  let web3Instance = web3
  return new Promise(function(resolve, reject) {
    web3Instance.currentProvider.send(param, function(err, data){
      if(err !== null) return reject(err);
      resolve(data);
    });
  });
}

const z = "0x8888888888888888888888888888888888888888888888888888888888888888";
const TOTAL_NUMBER = 16;
const MAIN_ACCOUNT = "0x2ad38f50f38abc5cbcf175e1962293eecc7936de";
const SECOND_ACCOUNT = "0x8b5432ca3423f3c310eba126c1d15809c61aa0a9";
const THIRD_ACCOUNT = "0xc21f17badcf5b3db4fdc825f9bc281245fe20c7d";

var truffle_dump =
    fs.readFileSync(
      "/home/augusto/contracts/build/contracts/ComputeInstantiator.json"
    ).toString('utf8');

abi = JSON.parse(truffle_dump).abi;

var myContract = new web3.eth.Contract(
  abi,
  process.env.CARTESI_MAIN_CONCERN_CONTRACT,
);

let claimer, challenger, duration;

async function main() {
  let current_index = parseInt(await myContract.methods.currentIndex().call());
  console.log("current index: " + current_index);
  for (var i = current_index; i < current_index + TOTAL_NUMBER; i++) {
    //console.log("i = " + i
    //            + ", current + total = " + (current_index + TOTAL_NUMBER));
    if (i & 1) {
      claimer = MAIN_ACCOUNT; // main account
    } else {
      claimer = THIRD_ACCOUNT;
    }
    challenger = SECOND_ACCOUNT;
    duration = "51";
    await myContract.methods.instantiate(
      challenger,
      claimer,
      duration,
      "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      z,
      "120",
    ).send({from: process.env.CARTESI_MAIN_CONCERN_USER,
            gas: "3000000"});
  }
  let new_index = await myContract.methods.currentIndex().call()
  console.log("new index: " + new_index);
  response = await sendRPC(web3, { jsonrpc: "2.0",
                                   method: "evm_increaseTime",
                                   params: [100], id: Date.now() });
  for (var i = current_index; i < current_index + TOTAL_NUMBER; i++) {
    if (i & 2) {
      await myContract.methods.claimVictoryByTime(i)
        .send({ from: challenger, gas: 1500000 })
        .catch((error) => {
          console.log("Error in claim victory. i = " + i
                      + " error = " + error);
        });
    }
    if (i & 4) {
      await myContract.methods.submitClaim(i, z)
        .send({ from: claimer, gas: 1500000 })
        .catch((error) => {
          console.log("Error in claim victory. i = " + i
                      + " error = " + error);
        });
    }
    if (i & 8) {
      await myContract.methods.challenge(i)
        .send({ from: challenger, gas: 1500000 })
        .catch((error) => {
          console.log("Error in claim victory. i = " + i
                      + " error = " + error);
        });
    }
  }

}



main();

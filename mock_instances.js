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

const initial_hash = "0xed93a94cd4ec8a56db5c0e7f0d5026adfe3f79a3a3057c38039da60f0c622e83";
const TOTAL_NUMBER = 1;
const MAIN_ACCOUNT = "0x2ad38f50f38abc5cbcf175e1962293eecc7936de";
const SECOND_ACCOUNT = "0x8b5432ca3423f3c310eba126c1d15809c61aa0a9";

var truffle_dump =
    fs.readFileSync(
      "/home/augusto/contracts/build/contracts/ComputeInstantiator.json"
    ).toString('utf8');

abi = JSON.parse(truffle_dump).abi;

var machine_address =
    fs.readFileSync(process.env.CARTESI_CONFIG_PATH + "_machine")
    .toString('utf8');

var myContract = new web3.eth.Contract(
  abi,
  process.env.CARTESI_MAIN_CONCERN_CONTRACT,
);

let claimer, challenger, duration;

async function main() {
  let current_index = parseInt(
    await myContract.methods.currentIndex().call()
  );
  for (var i = current_index; i < current_index + TOTAL_NUMBER; i++) {
    console.log("Creating instance: " + i);
    if (i & 1) {
      claimer = MAIN_ACCOUNT;
      challenger = SECOND_ACCOUNT;
    } else {
      claimer = SECOND_ACCOUNT;
      challenger = MAIN_ACCOUNT;
    }
    if (i & 2) {
      final_time = 10;
    } else {
      final_time = 120;
    }
    if (i & 4) {
      round_duration = 50;
    } else {
      round_duration = 100000;
    }
    console.log("Instance " + i + " has:");
    console.log("  challenger: " + challenger);
    console.log("  claimer: " + claimer);
    console.log("  round_duration: " + round_duration);
    console.log("  machine_address: " + machine_address);
    console.log("  initial_hash: " + initial_hash);
    console.log("  final_time: " + final_time);

    await myContract.methods.instantiate(
      challenger,
      claimer,
      round_duration,
      machine_address,
      initial_hash,
      final_time,
    ).send({from: process.env.CARTESI_MAIN_CONCERN_USER,
            gas: "3000000"})
      .then((receipt) => { console.log(receipt); });
  }
  let new_index = await myContract.methods.currentIndex().call()
  response = await sendRPC(web3, { jsonrpc: "2.0",
                                   method: "evm_increaseTime",
                                   params: [100], id: Date.now() });
}




main();

#!/usr/bin/node

const Web3 = require('web3');
const fs = require('fs');
var web3 = new Web3('http://127.0.0.1:8545');

const z = "0x8888888888888888888888888888888888888888888888888888888888888888";

var account = "0x45a64818b87f5310705CEc004438C7eC7Ed36368";
var private_key =
    "0x339565dd96968ad4fba67e320bc9cf07808298d3654634e1bcc3b46350964f6e";

var truffle_dump =
    fs.readFileSync(
      "/home/augusto/contracts/build/contracts/PartitionInstantiator.json"
    ).toString('utf8');

abi = JSON.parse(truffle_dump).abi;

var myContract = new web3.eth.Contract(
  abi,
  process.env.CONCERN_CONTRACT,
);

async function main() {
  for (var i = 0; i < 10; i++) {
    await myContract.methods.instantiate(
      "0x45a64818b87f5310705cec004438c7ec7ed36368", // this is the correct addr
      "0x45a64818b87f5310705cec004438c7ec7ed36363",
      z,
      z,
      "120",
      "10",
      "100",
    ).send({from: process.env.CONCERN_USER,
            gas: "3000000"});
    await myContract.methods.instantiate(
      "0x45a64818b87f5310705cec004438c7ec7ed36363",
      "0x45a64818b87f5310705cec004438c7ec7ed36361",
      z,
      z,
      "120",
      "10",
      "100",
    ).send({from: process.env.CONCERN_USER,
            gas: "3000000"});
  }

  console.log(await myContract.methods.currentIndex().call());
}

main();

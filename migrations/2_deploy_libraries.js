const yaml = require('js-yaml');
const fs   = require('fs');
var path = require('path');

//var Token = artifacts.require("./lib/bokkypoobah/Token.sol")
//var Strings = artifacts.require("./lib/strings.sol")

var rel = "../build/contracts";

var MMPath = path.join(__dirname, rel, "/MMInstantiator.json");
var SimpleMemoryPath = path.join(__dirname, rel, "/SimpleMemoryInstantiator.json");
var SubleqPath = path.join(__dirname, rel, "/Subleq.json");
var PartitionPath = path.join(__dirname, rel, "/PartitionInstantiator.json");
var VGPath = path.join(__dirname, rel, "/VGInstantiator.json");
var ComputePath = path.join(__dirname, rel, "/ComputeInstantiator.json");
var TestHashPath = path.join(__dirname, rel, "/TestHash.json");

var MMInstantiator = artifacts.require("./MMInstantiator.sol");
var SimpleMemoryInstantiator = artifacts.require("./SimpleMemoryInstantiator.sol");
var Subleq = artifacts.require("./Subleq.sol");
var PartitionInstantiator = artifacts.require("./PartitionInstantiator.sol");
var VGInstantiator = artifacts.require("./VGInstantiator.sol");
var ComputeInstantiator = artifacts.require("./ComputeInstantiator.sol");
var TestHash = artifacts.require("./TestHash.sol");

//test aux

var MMInstantiatorTestAux =
    artifacts.require("./testAuxiliaries/MMInstantiatorTestAux.sol");

//test aux
var PartitionTestAux =
    artifacts.require("./testAuxiliaries/PartitionTestAux.sol");

module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
    // await deployer.deploy(Token);
    await deployer.deploy(SimpleMemoryInstantiator);
    await deployer.deploy(Subleq);
    let SubleqContract = await Subleq.deployed();
    await deployer.deploy(PartitionInstantiator);
    let PartitionContract = await PartitionInstantiator.deployed();
    await deployer.deploy(MMInstantiator)
    let MMContract = await MMInstantiator.deployed();
    await deployer.deploy(VGInstantiator,
                          PartitionContract.address,
                          MMContract.address);
    let VGContract = await VGInstantiator.deployed();
    await deployer.deploy(ComputeInstantiator,
                          VGContract.address);
    let ComputeContract = await ComputeInstantiator.deployed();
    await deployer.deploy(PartitionTestAux);
    await deployer.deploy(MMInstantiatorTestAux);
    await deployer.deploy(TestHash);
    if (typeof process.env.CARTESI_CONFIG_PATH !== "undefined"){
      fs.writeFile(process.env.CARTESI_CONFIG_PATH, yaml.dump({
        url: "http://127.0.0.1:8545",
        max_delay: 500,
        warn_delay: 30,
        emulator_port: 50051,
        // main_concern: {
        //   contract_address: ComputeContract.address,
        //   user_address: accounts[0],
        //   abi: ComputePath,
        // },
        concerns: [
          { contract_address: PartitionContract.address,
            user_address: accounts[0],
            abi: PartitionPath,
          },
          { contract_address: MMContract.address,
            user_address: accounts[0],
            abi: MMPath,
          },
          { contract_address: VGContract.address,
            user_address: accounts[0],
            abi: VGPath,
          },
        ],
      }));
    }
  });
};



// module.exports = function(deployer) {
//   deployer.deploy(Token);
// //  deployer.deploy(Strings);
//   deployer.deploy(SimpleMemoryInstantiator);
//   deployer.deploy(Subleq);
//   deployer.deploy(PartitionInstantiator).then(function(){
//     return deployer.deploy(MMInstantiator).then(function() {
//       return deployer.deploy(
//         VGInstantiator,
//         PartitionInstantiator.address,
//         MMInstantiator.address).then(function() {
//           console.log("vg " + VGInstantiator.address);
//           return deployer.deploy(
//             ComputeInstantiator,
//             VGInstantiator.address).then(function() {
//               console.log("compute " + ComputeInstantiator.address);
//             });
//         });
//     })
//   })

//   deployer.deploy(PartitionTestAux);
//   deployer.deploy(MMInstantiatorTestAux);
// //  deployer.deploy(BitsManipulation);
//   deployer.deploy(TestHash);
// };

const yaml = require('js-yaml');
const fs   = require('fs');

//var Token = artifacts.require("./lib/bokkypoobah/Token.sol")
//var Strings = artifacts.require("./lib/strings.sol")

var MMPath = __dirname + "/MMInstantiator.sol";
var SimpleMemoryPath = __dirname + "/SimpleMemoryInstantiator.sol";
var SubleqPath = __dirname + "/Subleq.sol";
var PartitionPath = __dirname + "/PartitionInstantiator.sol";
var VGPath = __dirname + "/VGInstantiator.sol";
var ComputePath = __dirname + "/ComputeInstantiator.sol";
var TestHashPath = __dirname + "/TestHash.sol";

var MMInstantiator = artifacts.require(MMPath);
var SimpleMemoryInstantiator = artifacts.require(SimpleMemoryPath);
var Subleq = artifacts.require(SubleqPath);
var PartitionInstantiator = artifacts.require(PartitionPath);
var VGInstantiator = artifacts.require(VGPath);
var ComputeInstantiator = artifacts.require(ComputePath);
var TestHash = artifacts.require(TestHashPath);

//test aux

var MMInstantiatorTestAux = artifacts.require("./testAuxiliaries/MMInstantiatorTestAux.sol");

//test aux
var PartitionTestAux = artifacts.require("./testAuxiliaries/PartitionTestAux.sol");

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
    if (typeof process.env.CARTESI_CONFIG !== "undefined"){
      fs.writeFile(process.env.CARTESI_CONFIG, yaml.dump({
        url: "http://127.0.0.1:8545",
        max_delay: 500,
        warn_delay: 30,
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

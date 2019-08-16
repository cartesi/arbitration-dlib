const yaml = require('js-yaml');
const fs   = require('fs');
var path = require('path');

//var Token = artifacts.require("./lib/bokkypoobah/Token.sol")
//var Strings = artifacts.require("./lib/strings.sol")

var rel = "../build/contracts";

var MMPath = path.join(__dirname, rel, "/MMInstantiator.json");
var SimpleMemoryPath = path.join(__dirname, rel, "/SimpleMemoryInstantiator.json");
var HasherPath = path.join(__dirname, rel, "/Hasher.json");
var PartitionPath = path.join(__dirname, rel, "/PartitionInstantiator.json");
var VGPath = path.join(__dirname, rel, "/VGInstantiator.json");
var ComputePath = path.join(__dirname, rel, "/ComputeInstantiator.json");
var TestHashPath = path.join(__dirname, rel, "/TestHash.json");

var MMInstantiator = artifacts.require("./MMInstantiator.sol");
var SimpleMemoryInstantiator = artifacts.require("./SimpleMemoryInstantiator.sol");
var Hasher = artifacts.require("./Hasher.sol");
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
    await deployer.deploy(SimpleMemoryInstantiator);
    await deployer.deploy(PartitionInstantiator);
    let PartitionContract = await PartitionInstantiator.deployed();
    await deployer.deploy(MMInstantiator)
    let MMContract = await MMInstantiator.deployed();
    await deployer.deploy(VGInstantiator,
                          PartitionContract.address,
                          MMContract.address);
    await deployer.deploy(Hasher, MMContract.address);
    let HasherContract = await Hasher.deployed();
    let VGContract = await VGInstantiator.deployed();
    await deployer.deploy(ComputeInstantiator,
                          VGContract.address);
    let ComputeContract = await ComputeInstantiator.deployed();
    console.log("ComputeInstantiator: " + ComputeContract.address);
    await deployer.deploy(PartitionTestAux);
    await deployer.deploy(MMInstantiatorTestAux);
    await deployer.deploy(TestHash);
    if (typeof process.env.CARTESI_CONFIG_FILE_PATH !== "undefined"){
      fs.writeFileSync(process.env.CARTESI_CONFIG_FILE_PATH, yaml.dump({
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
          { contract_address: ComputeContract.address,
            user_address: accounts[0],
            abi: ComputePath,
          }
        ]
      }));
      fs.writeFileSync(process.env.MM_ADD_FILE_PATH,
        MMContract.address);
    }
  });
};

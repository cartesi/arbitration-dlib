var Token = artifacts.require("./lib/bokkypoobah/Token.sol")
var Strings = artifacts.require("./lib/strings.sol")
var MMInstantiator = artifacts.require("./MMInstantiator.sol");
var SimpleMemoryInstantiator = artifacts.require("./SimpleMemoryInstantiator.sol");
var Subleq = artifacts.require("./Subleq.sol");
var PartitionInstantiator = artifacts.require("./PartitionInstantiator.sol");
var DepthLib = artifacts.require("./DepthLib.sol");
var DepthInterface = artifacts.require("./DepthInterface.sol");
var VGInstantiator = artifacts.require("./VGInstantiator.sol");
var TestHash = artifacts.require("./TestHash.sol");

var BitsManipulation = artifacts.require("./lib/BitsManipulationLibrary.sol");
//test aux

var MMInstantiatorTestAux = artifacts.require("./testAuxiliaries/MMInstantiatorTestAux.sol");

//test aux
var PartitionTestAux = artifacts.require("./testAuxiliaries/PartitionTestAux.sol");

module.exports = function(deployer) {
  deployer.deploy(Token);
  deployer.deploy(Strings);
  deployer.deploy(MMInstantiator);
  deployer.deploy(SimpleMemoryInstantiator);
  deployer.deploy(Subleq);
  deployer.deploy(PartitionInstantiator);
  deployer.deploy(DepthLib);
  deployer.deploy(PartitionTestAux);
  deployer.deploy(MMInstantiatorTestAux);
  deployer.deploy(BitsManipulation);
  deployer.link(DepthLib, DepthInterface);
  deployer.deploy(TestHash);
};

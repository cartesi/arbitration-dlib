var Token = artifacts.require("./lib/bokkypoobah/Token.sol")
var MMInstantiator = artifacts.require("./MMInstantiator.sol");
var SimpleMemoryInstantiator = artifacts.require("./SimpleMemoryInstantiator.sol");
var Subleq = artifacts.require("./Subleq.sol");
var PartitionInstantiator = artifacts.require("./PartitionInstantiator.sol");
var DepthLib = artifacts.require("./DepthLib.sol");
var DepthInterface = artifacts.require("./DepthInterface.sol");
var VGInstantiator = artifacts.require("./VGInstantiator.sol");

//test aux

var MMInstantiatorTestAux = artifacts.require("./testAuxiliaries/MMInstantiatorTestAux.sol");

module.exports = function(deployer) {
  deployer.deploy(Token);
  deployer.deploy(MMInstantiator);
  deployer.deploy(SimpleMemoryInstantiator);
  deployer.deploy(Subleq);
  deployer.deploy(PartitionInstantiator);
  deployer.deploy(DepthLib);
  deployer.deploy(MMInstantiatorTestAux);
  deployer.link(DepthLib, DepthInterface);
};

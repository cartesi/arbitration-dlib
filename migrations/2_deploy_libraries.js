var MMInstantiator = artifacts.require("./MMInstantiator.sol");
var SimpleMemoryLib = artifacts.require("./SimpleMemoryLib.sol");
var SimpleMemoryInterface = artifacts.require("./SimpleMemoryInterface.sol");
var SubleqLib = artifacts.require("./SubleqLib.sol");
var SubleqInterface = artifacts.require("./SubleqInterface.sol");
var PartitionInstantiator = artifacts.require("./PartitionInstantiator.sol");
var DepthLib = artifacts.require("./DepthLib.sol");
var DepthInterface = artifacts.require("./DepthInterface.sol");
//var MCProtocol = artifacts.require("./MCProtocol.sol");

module.exports = function(deployer) {
  deployer.deploy(MMInstantiator);
  deployer.deploy(SimpleMemoryLib);
  deployer.link(SimpleMemoryLib, SimpleMemoryInterface);
  deployer.deploy(SubleqLib);
  deployer.link(SubleqLib, SubleqInterface);
  deployer.deploy(PartitionInstantiator);
  deployer.deploy(DepthLib);
  deployer.link(DepthLib, DepthInterface);
  // deployer.link(MMLib, MCProtocol);
  // deployer.link(SubleqLib, MCProtocol);
  // deployer.link(PartitionLib, MCProtocol);
  // deployer.deploy(MCProtocol);
};

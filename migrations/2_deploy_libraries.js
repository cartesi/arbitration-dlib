var MMLib = artifacts.require("./MMLib.sol");
var MMInterface = artifacts.require("./MMInterface.sol");
var SimpleMemoryLib = artifacts.require("./SimpleMemoryLib.sol");
var SimpleMemoryInterface = artifacts.require("./SimpleMemoryInterface.sol");
var SubleqLib = artifacts.require("./SubleqLib.sol");
var SubleqInterface = artifacts.require("./SubleqInterface.sol");
var PartitionLib = artifacts.require("./PartitionLib.sol");
var PartitionInterface = artifacts.require("./PartitionInterface.sol");
var DepthLib = artifacts.require("./DepthLib.sol");
var DepthInterface = artifacts.require("./DepthInterface.sol");
var MCProtocol = artifacts.require("./MCProtocol.sol");

module.exports = function(deployer) {
  deployer.deploy(MMLib);
  deployer.link(MMLib, MMInterface);
  deployer.deploy(SimpleMemoryLib);
  deployer.link(SimpleMemoryLib, SimpleMemoryInterface);
  deployer.deploy(SubleqLib);
  deployer.link(SubleqLib, SubleqInterface);
  deployer.deploy(PartitionLib);
  deployer.link(PartitionLib, PartitionInterface);
  deployer.deploy(DepthLib);
  deployer.link(DepthLib, DepthInterface);
  deployer.link(MMLib, MCProtocol);
  deployer.link(SubleqLib, MCProtocol);
  deployer.link(PartitionLib, MCProtocol);
  deployer.deploy(MCProtocol);
};

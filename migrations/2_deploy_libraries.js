var MMLib = artifacts.require("./MMLib.sol");
var MMInterface = artifacts.require("./MMInterface.sol");
var SimpleMemoryLib = artifacts.require("./SimpleMemoryLib.sol");
var SimpleMemoryInterface = artifacts.require("./SimpleMemoryInterface.sol");
var SubleqLib = artifacts.require("./SubleqLib.sol");
var SubleqInterface = artifacts.require("./SubleqInterface.sol");

module.exports = function(deployer) {
  deployer.deploy(MMLib);
  deployer.link(MMLib, MMInterface);
  deployer.deploy(SimpleMemoryLib);
  deployer.link(SimpleMemoryLib, SimpleMemoryInterface);
  deployer.deploy(SubleqLib);
  deployer.link(SubleqLib, SubleqInterface);
};

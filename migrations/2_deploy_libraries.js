var MMLib = artifacts.require("./MMLib.sol");
var MMInterface = artifacts.require("./MMInterface.sol");
var SubleqLib = artifacts.require("./SubleqLib.sol");
var SubleqInterface = artifacts.require("./SubleqInterface.sol");

module.exports = function(deployer) {
  deployer.deploy(MMLib);
  deployer.link(MMLib, MMInterface);
  deployer.deploy(SubleqLib);
  deployer.link(SubleqLib, SubleqInterface);
};

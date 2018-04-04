var MMLib = artifacts.require("./MMLib.sol");
var MMInterface = artifacts.require("./MMInterface.sol");

module.exports = function(deployer) {
  deployer.deploy(MMLib);
  deployer.link(MMLib, MMInterface);
  deployer.deploy(MMInterface);
};

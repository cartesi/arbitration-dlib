const PartitionInstantiator = artifacts.require("PartitionInstantiator");
const MMInstantiator = artifacts.require("MMInstantiator");
const VGInstantiator = artifacts.require("VGInstantiator");
const ComputeInstantiator = artifacts.require("ComputeInstantiator");

module.exports = function(deployer) {
  deployer.then(async () => {
    await deployer.deploy(PartitionInstantiator);
    await deployer.deploy(MMInstantiator);
    await deployer.deploy(VGInstantiator, PartitionInstantiator.address, MMInstantiator.address);
    await deployer.deploy(ComputeInstantiator, VGInstantiator.address);
  });
};

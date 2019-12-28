
const Hasher = artifacts.require("Hasher");
const MMInstantiatorTestAux = artifacts.require("test/MMInstantiatorTestAux");
const SimpleMemoryInstantiator = artifacts.require("test/SimpleMemoryInstantiator");
const PartitionTestAux = artifacts.require("test/PartitionTestAux");
const TestHash = artifacts.require("test/TestHash");

module.exports = function(deployer) {
  deployer.then(async () => {
    await deployer.deploy(MMInstantiatorTestAux);
    await deployer.deploy(SimpleMemoryInstantiator);
    await deployer.deploy(PartitionTestAux);
    await deployer.deploy(TestHash);
    await deployer.deploy(Hasher, MMInstantiatorTestAux.address);
  });
};

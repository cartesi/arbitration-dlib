import {
  BuidlerRuntimeEnvironment,
  DeployFunction
} from "@nomiclabs/buidler/types";

const func: DeployFunction = async (bre: BuidlerRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = bre;
  const { deploy } = deployments;
  const a = await getNamedAccounts();
  const { deployer } = await getNamedAccounts();

  const MMInstantiatorTestAux = await deploy("MMInstantiatorTestAux", { from: deployer, log: true });
  await deploy("SimpleMemoryInstantiator", { from: deployer, log: true });
  await deploy("PartitionTestAux", { from: deployer, log: true });
  await deploy("TestHash", { from: deployer, log: true });
  await deploy("Hasher", { from: deployer, log: true, args: [MMInstantiatorTestAux.address] });
};

export default func;
export const tags = ['Libs'];

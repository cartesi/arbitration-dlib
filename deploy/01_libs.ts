import {
    BuidlerRuntimeEnvironment,
    DeployFunction
} from "@nomiclabs/buidler/types";

const func: DeployFunction = async (bre: BuidlerRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = bre;
    const { deploy } = deployments;
    const a = await getNamedAccounts();
    const { deployer } = await getNamedAccounts();
    const { Merkle } = await deployments.all();

    const PartitionInstantiator = await deploy("PartitionInstantiator", {
        from: deployer,
        log: true
    });
    const MMInstantiator = await deploy("MMInstantiator", {
        from: deployer,
        libraries: {
            Merkle: Merkle.address
        },
        log: true
    });
    const VGInstantiator = await deploy("VGInstantiator", {
        from: deployer,
        log: true,
        args: [PartitionInstantiator.address, MMInstantiator.address]
    });
    await deploy("ComputeInstantiator", {
        from: deployer,
        log: true,
        args: [VGInstantiator.address]
    });
};

export default func;
export const tags = ["Libs"];

// Copyright (C) 2020 Cartesi Pte. Ltd.

// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.

// This program is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
// PARTICULAR PURPOSE. See the GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Note: This component currently has dependencies that are licensed under the GNU
// GPL, version 3, and so you should treat this component as a whole as being under
// the GPL version 3. But all Cartesi-written code in this component is licensed
// under the Apache License, version 2, or a compatible permissive license, and can
// be used independently under the Apache v2 license. After this component is
// rewritten, the entire component will be released under the Apache v2 license.

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async (bre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = bre;
    const { deploy, get } = deployments;
    const a = await getNamedAccounts();
    const { deployer } = await getNamedAccounts();

    // use pre-deployed Merkle, or deploy a new one (development/localhost)
    const Merkle = await get('Merkle');

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

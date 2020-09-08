// Arbitration DLib is the combination of the on-chain protocol and off-chain
// protocol that work together to resolve any disputes that might occur during the
// execution of a Cartesi DApp.

// Copyright (C) 2019 Cartesi Pte. Ltd.

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

use super::dispatcher::{AddressField, Bytes32Field, String32Field, U256Array};
use super::dispatcher::{Archive, DApp, Reaction};
use super::error::Result;
use super::error::*;
use super::ethabi::Token;
use super::ethereum_types::{Address, H256, U256};
use super::transaction::TransactionRequest;
use super::{Partition, Role, MM};
use compute::win_by_deadline_or_idle;
use mm::{MMCtx, MMCtxParsed, MMParams};
use partition::{PartitionCtx, PartitionCtxParsed};

pub struct VG();

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// these two structs and the From trait below shuld be
// obtained from a simple derive
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#[derive(Serialize, Deserialize)]
pub struct VGCtxParsed(
    AddressField,  // challenger
    AddressField,  // claimer
    AddressField,  // machine
    Bytes32Field,  // initialHash
    Bytes32Field,  // claimedFinalHash
    Bytes32Field,  // hashBeforeDivergence
    Bytes32Field,  // hashAfterDivergence
    String32Field, // currentState
    U256Array,     // uint values: finalTime
                   //              deadline
                   //              timeOfLastMove
                   //              mmInstance
                   //              partitionInstance
                   //              divergenceTime
);

#[derive(Serialize, Debug)]
pub struct VGCtx {
    pub challenger: Address,
    pub claimer: Address,
    pub machine: Address,
    pub initial_hash: H256,
    pub claimer_final_hash: H256,
    pub hash_before_divergence: H256,
    pub hash_after_divergence: H256,
    pub current_state: String,
    pub final_time: U256,
    pub deadline: U256,
    pub mm_instance: U256,
    pub partition_instance: U256,
    pub divergence_time: U256,
}

impl From<VGCtxParsed> for VGCtx {
    fn from(parsed: VGCtxParsed) -> VGCtx {
        VGCtx {
            challenger: parsed.0.value,
            claimer: parsed.1.value,
            machine: parsed.2.value,
            initial_hash: parsed.3.value,
            claimer_final_hash: parsed.4.value,
            hash_before_divergence: parsed.5.value,
            hash_after_divergence: parsed.6.value,
            current_state: parsed.7.value,
            final_time: parsed.8.value[0],
            deadline: parsed.8.value[1],
            mm_instance: parsed.8.value[2],
            partition_instance: parsed.8.value[3],
            divergence_time: parsed.8.value[4],
        }
    }
}

impl DApp<String> for VG {
    fn react(
        instance: &state::Instance,
        archive: &Archive,
        _post_payload: &Option<String>,
        machine_id: &String,
    ) -> Result<Reaction> {
        let parsed: VGCtxParsed = serde_json::from_str(&instance.json_data).chain_err(|| {
            format!(
                "Could not parse vg instance json_data: {}",
                &instance.json_data
            )
        })?;
        let ctx: VGCtx = parsed.into();
        trace!("Context for vg (index {}) {:?}", instance.index, ctx);

        // should not happen as it indicates an innactive instance,
        // but it is possible that the blockchain state changed between queries
        match ctx.current_state.as_ref() {
            "FinishedClaimerWon" | "FinishedChallengerWon" => {
                return Ok(Reaction::Idle);
            }
            _ => {}
        };

        // if we reach this code, the instance is active, get role of user
        let role = match instance.concern.user_address {
            cl if (cl == ctx.claimer) => Role::Claimer,
            ch if (ch == ctx.challenger) => Role::Challenger,
            _ => {
                return Err(Error::from(ErrorKind::InvalidContractState(String::from(
                    "User is neither claimer nor challenger",
                ))));
            }
        };
        trace!("Role played (index {}) is: {:?}", instance.index, role);

        match role {
            Role::Claimer => match ctx.current_state.as_ref() {
                "WaitPartition" => {
                    // get the partition instance to see if its is finished
                    let partition_instance = instance.sub_instances.get(0).ok_or(Error::from(
                        ErrorKind::InvalidContractState(format!(
                            "There is no partition instance {}",
                            ctx.current_state
                        )),
                    ))?;

                    let partition_parsed: PartitionCtxParsed =
                        serde_json::from_str(&partition_instance.json_data).chain_err(|| {
                            format!(
                                "Could not parse partition instance json_data: {}",
                                &instance.json_data
                            )
                        })?;
                    let partition_ctx: PartitionCtx = partition_parsed.into();

                    match partition_ctx.current_state.as_ref() {
                        "ClaimerWon" => {
                            // claim victory by partition timeout
                            info!(
                                "Claiming victory by Partition timeout (index: {})",
                                instance.index
                            );
                            let request = TransactionRequest {
                                contract_name: None, // Name not needed, is concern
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "winByPartitionTimeout".into(),
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                // improve these types by letting the
                                // dapp submit ethereum_types and convert
                                // them inside the transaction manager
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                data: vec![Token::Uint(instance.index)],
                                gas: None,
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }
                        "DivergenceFound" => {
                            // start the machine run challenge
                            info!(
                                "Starting machine run challenage for VG (index: {})",
                                instance.index
                            );
                            let request = TransactionRequest {
                                contract_name: None, // Name not needed, is concern
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "startMachineRunChallenge".into(),
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                // improve these types by letting the
                                // dapp submit ethereum_types and convert
                                // them inside the transaction manager
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                data: vec![Token::Uint(instance.index)],
                                gas: None,
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }
                        _ => {
                            // partition is still running,
                            // pass control to the partition dapp
                            return Partition::react(
                                partition_instance,
                                archive,
                                &None,
                                &machine_id,
                            );
                        }
                    }
                }
                "WaitMemoryProveValues" => {
                    return win_by_deadline_or_idle(
                        &instance.concern,
                        instance.index,
                        ctx.deadline.as_u64(),
                    );
                }
                _ => {
                    return Err(Error::from(ErrorKind::InvalidContractState(format!(
                        "Unknown current state {}",
                        ctx.current_state
                    ))));
                }
            },
            Role::Challenger => match ctx.current_state.as_ref() {
                "WaitPartition" => {
                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    // deduplicate code with wait partition above
                    // not quite the same
                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    // get the partition instance to see if its is finished
                    let partition_instance = instance.sub_instances.get(0).ok_or(Error::from(
                        ErrorKind::InvalidContractState(format!(
                            "There is no partition instance {}",
                            ctx.current_state
                        )),
                    ))?;

                    let partition_parsed: PartitionCtxParsed =
                        serde_json::from_str(&partition_instance.json_data).chain_err(|| {
                            format!(
                                "Could not parse partition instance json_data: {}",
                                &instance.json_data
                            )
                        })?;
                    let partition_ctx: PartitionCtx = partition_parsed.into();

                    match partition_ctx.current_state.as_ref() {
                        "ChallengerWon" => {
                            // claim victory by partition timeout
                            info!(
                                "Claiming victory by Partition timeout (index: {})",
                                instance.index
                            );
                            let request = TransactionRequest {
                                contract_name: None, // Name not needed, is concern
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "winByPartitionTimeout".into(),
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                // improve these types by letting the
                                // dapp submit ethereum_types and convert
                                // them inside the transaction manager
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                data: vec![Token::Uint(instance.index)],
                                gas: None,
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }
                        "DivergenceFound" => {
                            // start the machine run challenge
                            info!(
                                "Starting machine run challenage for VG (index: {})",
                                instance.index
                            );
                            let request = TransactionRequest {
                                contract_name: None, // Name not needed, is concern
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "startMachineRunChallenge".into(),
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                // improve these types by letting the
                                // dapp submit ethereum_types and convert
                                // them inside the transaction manager
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                data: vec![Token::Uint(instance.index)],
                                gas: None,
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }
                        _ => {
                            // partition is still running,
                            // pass control to the partition dapp
                            return Partition::react(
                                partition_instance,
                                archive,
                                &None,
                                machine_id,
                            );
                        }
                    }
                }
                "WaitMemoryProveValues" => {
                    let mm_instance = instance.sub_instances.get(0).ok_or(Error::from(
                        ErrorKind::InvalidContractState(format!(
                            "There is no memory manager instance {}",
                            ctx.current_state
                        )),
                    ))?;

                    let mm_parsed: MMCtxParsed = serde_json::from_str(&mm_instance.json_data)
                        .chain_err(|| {
                            format!(
                                "Could not parse mm instance json_data: {}",
                                &instance.json_data
                            )
                        })?;
                    let mm_ctx: MMCtx = mm_parsed.into();

                    match mm_ctx.current_state.as_ref() {
                        "WaitingProofs" => {
                            let params = MMParams {
                                divergence_time: ctx.divergence_time,
                                machine_id: machine_id.clone(),
                            };
                            return MM::react(mm_instance, archive, &None, &params);
                        }
                        "WaitingReplay" => {
                            // start the machine run challenge
                            info!("Settling VG (index: {})", instance.index);
                            let request = TransactionRequest {
                                contract_name: None, // Name not needed, is concern
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "settleVerificationGame".into(),
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                // improve these types by letting the
                                // dapp submit ethereum_types and convert
                                // them inside the transaction manager
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                data: vec![Token::Uint(instance.index)],
                                gas: None,
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }
                        "FinishedReplay" => {
                            warn!("Strange state for vg and mm");
                            return Ok(Reaction::Idle);
                        }
                        _ => {
                            warn!("Unknown state for vg and mm");
                            return Ok(Reaction::Idle);
                        }
                    }
                }
                _ => {
                    return Err(Error::from(ErrorKind::InvalidContractState(format!(
                        "Unknown current state {}",
                        ctx.current_state
                    ))));
                }
            },
        }
    }

    fn get_pretty_instance(
        instance: &state::Instance,
        archive: &Archive,
        machine_id: &String,
    ) -> Result<state::Instance> {
        // get context (state) of the vg instance
        let parsed: VGCtxParsed = serde_json::from_str(&instance.json_data).chain_err(|| {
            format!(
                "Could not parse vg instance json_data: {}",
                &instance.json_data
            )
        })?;
        let ctx: VGCtx = parsed.into();
        let json_data = serde_json::to_string(&ctx).unwrap();

        // get context (state) of the sub instances

        let mut pretty_sub_instances: Vec<Box<state::Instance>> = vec![];

        match ctx.current_state.as_ref() {
            "WaitPartition" => {
                for sub in &instance.sub_instances {
                    pretty_sub_instances.push(Box::new(
                        Partition::get_pretty_instance(sub, archive, machine_id).unwrap(),
                    ))
                }
            }
            "WaitMemoryProveValues" => {
                let params = MMParams {
                    divergence_time: ctx.divergence_time,
                    machine_id: machine_id.clone(),
                };
                for sub in &instance.sub_instances {
                    pretty_sub_instances.push(Box::new(
                        MM::get_pretty_instance(sub, archive, &params).unwrap(),
                    ))
                }
            }
            _ => {}
        }

        let pretty_instance = state::Instance {
            name: "VG".to_string(),
            concern: instance.concern.clone(),
            index: instance.index,
            service_status: archive.get_service("VG".into()),
            json_data: json_data,
            sub_instances: pretty_sub_instances,
        };

        return Ok(pretty_instance);
    }
}
#[cfg(test)]
mod tests {

    use super::*;
    use ethereum_types::H160;

    use mm;
    use partition;

    fn build_vg_state_json_data(current_state: &str, deadline: Option<&str>) -> String {
        let _deadline = deadline.unwrap_or("0x0");
        let data = serde_json::json!([
        {"name": "challenger",
        "value": "0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818",
        "type": "address"},

        {"name": "claimer",
        "value": "0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020",
        "type": "address"},

        {"name": "machine",
        "value": "0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23940000",
        "type": "address"},

        {"name": "initial_hash",
        "value": "0xa70817cd86277772e8f71cfe28d32da866b05f981d80e4d17eae915321930000",
        "type": "bytes32"},

        {"name": "claimer_final_hash",
        "value": "0xa70817cd86277772e8f71cfe28d32da866b05f981d80e4d17eae915321930001",
        "type": "bytes32"},

        {"name": "hash_before_divergence",
        "value": "0xa70817cd86277772e8f71cfe28d32da866b05f981d80e4d17eae915321930002",
        "type": "bytes32"},

        {"name": "hash_after_divergence",
        "value": "0xa70817cd86277772e8f71cfe28d32da866b05f981d80e4d17eae915321930003",
        "type": "bytes32"},

        {"name": "currentState",
        "value": current_state,
        "type": "bytes"},

        {"name": "response",
        "value": ["0x0",_deadline, "0x0", "0x0","0x0", "0x0"],
        "type": "uint256[]"}]);
        return String::from(serde_json::to_string(&data).unwrap());
    }

    fn build_service_status() -> state::ServiceStatus {
        state::ServiceStatus {
            service_name: "".into(),
            service_method: "".into(),
            status: 0,
            description: "".into(),
            progress: 0,
        }
    }

    fn hash_from_string<'de, T: serde::Deserialize<'de>>(hash: &'de str) -> T {
        serde_json::from_str::<T>(hash).unwrap()
    }

    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
    #[test]
    #[should_panic(expected = "Unknown current state Hello World!")]
    fn it_should_be_idle() {
        let current_state = "0x46696e69736865644368616c6c656e676572576f6e"; // FinishedChallengerWon,
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020\"",
            ),
        };
        let default_status = build_service_status();

        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_vg_state_json_data(current_state, None),
            sub_instances,
        };
        {
            // ChallengerWon
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            // ClaimerWon
            let current_state = "0x46696e6973686564436c61696d6572576f6e"; // FinishedClaimerWon
            state_instance.json_data = build_vg_state_json_data(current_state, None);
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            // Hello World! // it should not work so it will panic
            let current_state = "0x48656c6c6f20576f726c6421"; // Hello World!
            state_instance.json_data = build_vg_state_json_data(current_state, None);
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
    }

    #[test]
    fn it_should_call_win_by_deadline_as_claimer() {
        let current_state = "0x576169744d656d6f727950726f766556616c756573"; // WaitMemoryProveValues,
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020\"", //claimer
            ),
        };
        let default_status = build_service_status();

        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_vg_state_json_data(current_state, None),
            sub_instances,
        };
        {
            // ChallengerWon
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "claimVictoryByTime");
            } else {
                panic!("Only transaction");
            }
        }
        {
            // Idle
            let deadline = "0x1fffffffffffff";
            state_instance.json_data =
                build_vg_state_json_data(current_state, Option::from(deadline));
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
    }

    #[test]
    #[should_panic(expected = "Unknown current state Hello World!")]
    fn it_should_call_wait_partition_as_claimer() {
        let current_state = "0x57616974506172746974696f6e"; // WaitPartition
        let current_state_partition = "0x436c61696d6572576f6e"; // ClaimerWon
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020\"", //claimer
            ),
        };
        let default_status = build_service_status();
        let mut partition_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status.clone(),
            json_data: partition::tests::build_state_json_data(
                current_state_partition,
                None,
                None,
                None,
                None,
            ),
            sub_instances: vec![],
        };

        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_vg_state_json_data(current_state, None),
            sub_instances: vec![Box::from(partition_instance.clone())],
        };
        {
            // Claimer won
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "winByPartitionTimeout");
            } else {
                panic!("Only transaction");
            }
        }
        {
            // DivergenceFound
            let current_state_partition = "0x446976657267656e6365466f756e64"; // DivergenceFound
            partition_instance.json_data = partition::tests::build_state_json_data(
                current_state_partition,
                None,
                None,
                None,
                None,
            );
            state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "startMachineRunChallenge");
            } else {
                panic!("Only transaction");
            }
        }
        {
            // DivergenceFound
            let current_state_partition = "0x48656c6c6f20576f726c6421"; // Hello World!
            partition_instance.json_data = partition::tests::build_state_json_data(
                current_state_partition,
                None,
                None,
                None,
                None,
            );
            state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            panic!("Should have erroed already");
        }
    }

    #[test]
    #[should_panic(expected = "Unknown current state Unknown")]
    fn it_should_wait_partition_as_challenger() {
        let current_state = "0x57616974506172746974696f6e"; // WaitPartition
        let current_state_partition = "0x446976657267656e6365466f756e64"; // DivergenceFound
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"", //challenger
            ),
        };
        let default_status = build_service_status();
        let mut partition_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status.clone(),
            json_data: partition::tests::build_state_json_data(
                current_state_partition,
                None,
                None,
                None,
                None,
            ),
            sub_instances: vec![],
        };

        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_vg_state_json_data(current_state, None),
            sub_instances: vec![Box::from(partition_instance.clone())],
        };
        {
            // DivergenceFound
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "startMachineRunChallenge");
            } else {
                panic!("Only transaction");
            }
        }
        {
            // ChallengerWon
            let current_state_partition = "0x4368616c6c656e676572576f6e"; // ChallengerWon
            partition_instance.json_data = partition::tests::build_state_json_data(
                current_state_partition,
                None,
                None,
                None,
                None,
            );
            state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "winByPartitionTimeout");
            } else {
                panic!("Only transaction");
            }
        }
        { 
            //pass control to the partition dapp
            let current_state_partition = "0x556e6b6e6f776e"; // Unknown
            partition_instance.json_data = partition::tests::build_state_json_data(
                current_state_partition,
                None,
                None,
                None,
                None,
            );
            state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
            VG::react(&state_instance, &archive, &None, &machine_id).unwrap();
            panic!("Should've errored already");
        }
    }

    #[test]
    #[should_panic(expected = "ResponseMissError")]
    fn it_should_wait_memory_prove_as_challenger() {
        // WaitMemoryProveValues
        let machine_id = String::from("Machine000");
        let current_state = "0x576169744d656d6f727950726f766556616c756573"; // WaitMemoryProveValues
        let current_state_mm = "0x57616974696e675265706c6179"; // WaitingReplay
        let default_status = build_service_status();
        let archive = Archive::new().unwrap();

        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"", //challenger
            ),
        };
        let mut mm_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status.clone(),
            json_data: mm::tests::build_mm_state_json_data(current_state_mm, None),
            sub_instances: vec![],
        };
        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_vg_state_json_data(current_state, None),
            sub_instances: vec![Box::from(mm_instance.clone())],
        };
        {
            //WaitingReplay
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "settleVerificationGame");
            } else {
                panic!("Only transaction");
            }
        }
        {
            //FinishedReplay
            let current_state_mm = "0x46696e69736865645265706c6179"; // FinishedReplay
            mm_instance.json_data =  mm::tests::build_mm_state_json_data(current_state_mm, None);
            state_instance.sub_instances = vec![Box::from(mm_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            //Unkonw state
            let current_state_mm = "0x48656c6c6f20576f726c6421"; // Hello World!
            mm_instance.json_data =  mm::tests::build_mm_state_json_data(current_state_mm, None);
            state_instance.sub_instances = vec![Box::from(mm_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            //WaitingProofs
            let current_state_mm = "0x57616974696e6750726f6f6673"; // WaitingProofs
            mm_instance.json_data =  mm::tests::build_mm_state_json_data(current_state_mm, None);
            state_instance.sub_instances = vec![Box::from(mm_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &machine_id).unwrap();
        }
    }
    #[test]
    fn it_should_call_get_pretty_instance() {
        let current_state = "0x57616974506172746974696f6e"; // WaitPartition
        let current_state_partition = "0x446976657267656e6365466f756e64"; // DivergenceFound
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"", //challenger
            ),
        };
        let default_status = build_service_status();
        let partition_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status.clone(),
            json_data: partition::tests::build_state_json_data(
                current_state_partition,
                None,
                None,
                None,
                None,
            ),
            sub_instances: vec![],
        };

        let state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status.clone(),
            json_data: build_vg_state_json_data(current_state, None),
            sub_instances: vec![Box::from(partition_instance.clone())],
        };
        {
            //WaitPartition
            let result = VG::get_pretty_instance(&state_instance, &archive, &machine_id).unwrap();
            assert_eq!("VG", result.name);
            assert_eq!(concern, result.concern);
            assert_eq!(state_instance.index, result.index);

            let pretty_json: serde_json::value::Value =
                serde_json::from_str(&result.json_data).unwrap();
            assert!(pretty_json.is_object());
            assert_eq!(
                serde_json::json!("0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818".to_lowercase()),
                pretty_json["challenger"]
            );
            assert_eq!(serde_json::json!("0x0"), pretty_json["deadline"]);
            assert_eq!(
                serde_json::json!("WaitPartition"),
                pretty_json["current_state"]
            );

            let pretty_sub = result.sub_instances.get(0).unwrap();
            assert!(pretty_json.is_object());
            let pretty_sub_json: serde_json::value::Value =
                serde_json::from_str(&pretty_sub.json_data).unwrap();
            assert!(pretty_sub_json.is_object());
            assert_eq!(
                serde_json::json!("DivergenceFound"),
                pretty_sub_json["current_state"]
            );
        }
        {
            // WaitMemoryProveValues
            let current_state = "0x576169744d656d6f727950726f766556616c756573"; // WaitMemoryProveValues
            let current_state_mm = "0x4368616c6c656e676572576f6e"; // ChallengerWon
            let mm_instance = state::Instance {
                name: "".to_string(),
                concern,
                index: U256::from(0),
                service_status: default_status.clone(),
                json_data: mm::tests::build_mm_state_json_data(current_state_mm, None),
                sub_instances: vec![],
            };
            let state_instance = state::Instance {
                name: "".to_string(),
                concern,
                index: U256::from(0),
                service_status: default_status,
                json_data: build_vg_state_json_data(current_state, None),
                sub_instances: vec![Box::from(mm_instance.clone())],
            };

            let result = VG::get_pretty_instance(&state_instance, &archive, &machine_id).unwrap();
            assert_eq!("VG", result.name);
            assert_eq!(concern, result.concern);
            assert_eq!(state_instance.index, result.index);
            let pretty_json: serde_json::value::Value =
                serde_json::from_str(&result.json_data).unwrap();
            assert!(pretty_json.is_object());
            assert_eq!(
                serde_json::json!("WaitMemoryProveValues"),
                pretty_json["current_state"]
            );

            let pretty_sub = result.sub_instances.get(0).unwrap();
            assert!(pretty_json.is_object());
            let pretty_sub_json: serde_json::value::Value =
                serde_json::from_str(&pretty_sub.json_data).unwrap();
            assert!(pretty_sub_json.is_object());
            assert_eq!(
                serde_json::json!("ChallengerWon"),
                pretty_sub_json["current_state"]
            );
            assert_eq!(serde_json::json!("0x0"), pretty_sub_json["history_length"]);
        }
    }
}

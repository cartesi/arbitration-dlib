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
use super::win_by_deadline_or_idle;
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
    use mm;
    use partition;
    use tests::{
        build_concern, build_service_status, build_state, encode, CHALLENGERADDR, CLAIMERADDR,
        MACHINEADDR, MACHINEID, UNKNOWNSTATE,
    };

    fn build_vg_state_json_data(current_state: &str, deadline: Option<&str>) -> String {
        let _deadline = deadline.unwrap_or("0x0");
        let data = serde_json::json!([
        {"name": "challenger",
        "value": CHALLENGERADDR,
        "type": "address"},

        {"name": "claimer",
        "value": CLAIMERADDR,
        "type": "address"},

        {"name": "machine",
        "value": MACHINEADDR,
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

    #[test]
    #[should_panic(expected = "Unknown current state Unknown State")]
    fn it_should_be_idle() {
        let current_state = encode("FinishedChallengerWon");
        let archive = Archive::new().unwrap();
        let concern = build_concern(CLAIMERADDR);

        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);

        {
            // ChallengerWon
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            // ClaimerWon
            let current_state = encode("FinishedClaimerWon"); // FinishedClaimerWon
            state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            // UNKNOWNSTATE // it should not work so it will panic
            let current_state = encode(UNKNOWNSTATE);
            state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
    }

    #[test]
    fn it_should_call_win_by_deadline_as_claimer() {
        let current_state = encode("WaitMemoryProveValues");
        let archive = Archive::new().unwrap();
        let concern = build_concern(CLAIMERADDR);

        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);
        {
            // ChallengerWon
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
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
                build_vg_state_json_data(current_state.as_str(), Option::from(deadline));
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
    }

    #[test]
    #[should_panic(expected = "Unknown current state Unknown State")]
    fn it_should_call_wait_partition_as_claimer() {
        let current_state = encode("WaitPartition");
        let current_state_partition = encode("ClaimerWon");
        let archive = Archive::new().unwrap();
        let concern = build_concern(CLAIMERADDR);
        let mut partition_instance = build_state(concern, None);
        partition_instance.json_data = partition::tests::build_partition_state_json_data(
            current_state_partition.as_str(),
            None,
            None,
            None,
            None,
        );

        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);
        state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
        {
            // Claimer won
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
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
            let current_state_partition = encode("DivergenceFound");
            partition_instance.json_data = partition::tests::build_partition_state_json_data(
                current_state_partition.as_str(),
                None,
                None,
                None,
                None,
            );
            state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
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
            let current_state_partition = encode(UNKNOWNSTATE);
            partition_instance.json_data = partition::tests::build_partition_state_json_data(
                current_state_partition.as_str(),
                None,
                None,
                None,
                None,
            );
            state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
            let mut _reaction = result.unwrap();
            panic!("Should have erroed already");
        }
    }

    #[test]
    #[should_panic(expected = "Unknown current state Unknown")]
    fn it_should_wait_partition_as_challenger() {
        let current_state = encode("WaitPartition");
        let current_state_partition = encode("DivergenceFound");
        let archive = Archive::new().unwrap();
        let concern = build_concern(CHALLENGERADDR);
        let mut partition_instance = build_state(concern, None);
        partition_instance.json_data = partition::tests::build_partition_state_json_data(
            current_state_partition.as_str(),
            None,
            None,
            None,
            None,
        );
        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);
        state_instance.sub_instances = vec![Box::from(partition_instance.clone())];

        {
            // DivergenceFound
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
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
            let current_state_partition = encode("ChallengerWon");
            partition_instance.json_data = partition::tests::build_partition_state_json_data(
                current_state_partition.as_str(),
                None,
                None,
                None,
                None,
            );
            state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
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
            let current_state_partition = encode(UNKNOWNSTATE);
            partition_instance.json_data = partition::tests::build_partition_state_json_data(
                current_state_partition.as_str(),
                None,
                None,
                None,
                None,
            );
            state_instance.sub_instances = vec![Box::from(partition_instance.clone())];
            VG::react(&state_instance, &archive, &None, &String::from(MACHINEID)).unwrap();
            panic!("Should've errored already");
        }
    }

    #[test]
    #[should_panic(expected = "ResponseMissError")]
    fn it_should_wait_memory_prove_as_challenger() {
        // WaitMemoryProveValues
        let current_state = encode("WaitMemoryProveValues");
        let current_state_mm = encode("WaitingReplay");
        let archive = Archive::new().unwrap();
        let concern = build_concern(CHALLENGERADDR);

        let mut mm_instance = build_state(concern, None);
        mm_instance.json_data =
            mm::tests::build_mm_state_json_data(current_state_mm.as_str(), None);

        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);
        state_instance.sub_instances = vec![Box::from(mm_instance.clone())];

        {
            //WaitingReplay
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
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
            let current_state_mm = encode("FinishedReplay");
            mm_instance.json_data =
                mm::tests::build_mm_state_json_data(current_state_mm.as_str(), None);
            state_instance.sub_instances = vec![Box::from(mm_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            //Unkonw state
            let current_state_mm = encode(UNKNOWNSTATE);
            mm_instance.json_data =
                mm::tests::build_mm_state_json_data(current_state_mm.as_str(), None);
            state_instance.sub_instances = vec![Box::from(mm_instance.clone())];
            let result = VG::react(&state_instance, &archive, &None, &String::from(MACHINEID));
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            //WaitingProofs
            let current_state_mm = encode("WaitingProofs");
            mm_instance.json_data =
                mm::tests::build_mm_state_json_data(current_state_mm.as_str(), None);
            state_instance.sub_instances = vec![Box::from(mm_instance.clone())];
            let _result =
                VG::react(&state_instance, &archive, &None, &String::from(MACHINEID)).unwrap();
        }
    }
    #[test]
    fn it_should_call_get_pretty_instance() {
        let current_state = encode("WaitPartition");
        let current_state_partition = encode("DivergenceFound");
        let archive = Archive::new().unwrap();
        let concern = build_concern(CHALLENGERADDR);
        let mut partition_instance = build_state(concern, None);
        partition_instance.json_data = partition::tests::build_partition_state_json_data(
            current_state_partition.as_str(),
            None,
            None,
            None,
            None,
        );
        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);
        state_instance.sub_instances = vec![Box::from(partition_instance.clone())];

        {
            //WaitPartition
            let result =
                VG::get_pretty_instance(&state_instance, &archive, &String::from(MACHINEID))
                    .unwrap();
            assert_eq!("VG", result.name);
            assert_eq!(concern, result.concern);
            assert_eq!(state_instance.index, result.index);

            let pretty_json: serde_json::value::Value =
                serde_json::from_str(&result.json_data).unwrap();
            assert!(pretty_json.is_object());
            assert_eq!(
                serde_json::json!(CHALLENGERADDR.to_lowercase()),
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
            let current_state = encode("WaitMemoryProveValues");
            let current_state_mm = encode("ChallengerWon");
            let mut mm_instance = build_state(concern, None);
            mm_instance.json_data =
                mm::tests::build_mm_state_json_data(current_state_mm.as_str(), None);

            state_instance.json_data = build_vg_state_json_data(current_state.as_str(), None);
            state_instance.sub_instances = vec![Box::from(mm_instance.clone())];

            let result =
                VG::get_pretty_instance(&state_instance, &archive, &String::from(MACHINEID))
                    .unwrap();
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

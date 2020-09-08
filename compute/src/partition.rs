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

use super::build_session_run_key;
use super::dispatcher::{AddressField, BoolArray, Bytes32Array, String32Field, U256Array};
use super::dispatcher::{Archive, DApp, Reaction};
use super::error::Result;
use super::error::*;
use super::ethabi::Token;
use super::ethereum_types::{Address, H256, U256};
use super::transaction::TransactionRequest;
use super::win_by_deadline_or_idle;
use super::{get_run_result, Role};
use emulator_service::SessionRunRequest;

pub struct Partition();

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// these two structs and the From trait below shuld be
// obtained from a simple derive
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#[derive(Serialize, Deserialize)]
pub struct PartitionCtxParsed(
    pub AddressField,  // challenger
    pub AddressField,  // claimer
    pub U256Array,     // queryArray
    pub BoolArray,     // submittedArray
    pub Bytes32Array,  // hashArray
    pub String32Field, // currentState
    pub U256Array,     // uint values: finalTime
                       // querySize
                       // deadline
                       // divergenceTime
);

#[derive(Serialize, Debug)]
pub struct PartitionCtx {
    pub challenger: Address,
    pub claimer: Address,
    pub query_array: Vec<U256>,
    pub submitted_array: Vec<bool>,
    pub hash_array: Vec<H256>,
    pub current_state: String,
    pub final_time: U256,
    pub query_size: U256,
    pub deadline: U256,
    pub divergence_time: U256,
}

impl From<PartitionCtxParsed> for PartitionCtx {
    fn from(parsed: PartitionCtxParsed) -> PartitionCtx {
        PartitionCtx {
            challenger: parsed.0.value,
            claimer: parsed.1.value,
            query_array: parsed.2.value,
            submitted_array: parsed.3.value,
            hash_array: parsed.4.value,
            current_state: parsed.5.value,
            final_time: parsed.6.value[0],
            query_size: parsed.6.value[1],
            deadline: parsed.6.value[2],
            divergence_time: parsed.6.value[3],
        }
    }
}

impl DApp<String> for Partition {
    fn react(
        instance: &state::Instance,
        archive: &Archive,
        _post_payload: &Option<String>,
        machine_id: &String,
    ) -> Result<Reaction> {
        let parsed: PartitionCtxParsed =
            serde_json::from_str(&instance.json_data).chain_err(|| {
                format!(
                    "Could not parse partition instance json_data: {}",
                    &instance.json_data
                )
            })?;
        let ctx: PartitionCtx = parsed.into();
        trace!("Context for parition {:?}", ctx);

        // should not happen as it indicates an innactive instance,
        // but it is possible that the blockchain state changed between queries
        match ctx.current_state.as_ref() {
            "ChallengerWon" | "ClaimerWon" | "DivergenceFound" => {
                return Ok(Reaction::Idle);
            }
            _ => {}
        };

        // if we reach this code, the instance is active, get user's role
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
                "WaitingQuery" => {
                    return win_by_deadline_or_idle(
                        &instance.concern,
                        instance.index,
                        ctx.deadline.as_u64(),
                    );
                }
                "WaitingHashes" => {
                    // machine id
                    let id = machine_id.clone();

                    trace!("Calculating queried hashes of machine {}", id);
                    let sample_points: Vec<u64> = ctx
                        .query_array
                        .clone()
                        .into_iter()
                        .map(|u| u.as_u64())
                        .collect();
                    let request = SessionRunRequest {
                        session_id: id.clone(),
                        times: sample_points.clone(),
                    };
                    let archive_key = build_session_run_key(id.clone(), sample_points.clone());
                    // have we sampled the times?
                    let processed_result = get_run_result(
                        archive,
                        "Partition".to_string(),
                        archive_key,
                        request.into(),
                    )?;

                    let mut hashes = Vec::new();

                    for i in 0..ctx.query_size.as_usize() {
                        // get the i'th time in query array
                        let _time = &ctx.query_array.get(i).ok_or(Error::from(
                            ErrorKind::InvalidContractState(String::from(
                                "could not find element in query array",
                            )),
                        ))?;
                        let hash = processed_result.hashes.get(i).unwrap();
                        hashes.push(hash);
                    }
                    // submit the required hashes
                    info!("Replying Query for Partition (index: {})", instance.index);
                    let request = TransactionRequest {
                        contract_name: None, // Name not needed, is concern
                        concern: instance.concern.clone(),
                        value: U256::from(0),
                        function: "replyQuery".into(),
                        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                        // improve these types by letting the
                        // dapp submit ethereum_types and convert
                        // them inside the transaction manager
                        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                        data: vec![
                            Token::Uint(instance.index),
                            Token::Array(
                                ctx.query_array
                                    .clone()
                                    .iter_mut()
                                    .map(|q: &mut U256| -> _ { Token::Uint(q.clone()) })
                                    .collect(),
                            ),
                            Token::Array(
                                hashes
                                    .into_iter()
                                    .map(|h| -> _ {
                                        Token::FixedBytes(h.clone().to_fixed_bytes().to_vec())
                                    })
                                    .collect(),
                            ),
                        ],
                        gas: None,
                        strategy: transaction::Strategy::Simplest,
                    };
                    return Ok(Reaction::Transaction(request));
                }
                _ => {
                    return Err(Error::from(ErrorKind::InvalidContractState(format!(
                        "Unknown current state {}",
                        ctx.current_state
                    ))));
                }
            },
            Role::Challenger => match ctx.current_state.as_ref() {
                "WaitingQuery" => {
                    // machine id
                    let id = machine_id.clone();

                    trace!("Calculating posted hashes of machine {}", id);
                    let sample_points: Vec<u64> = ctx
                        .query_array
                        .clone()
                        .into_iter()
                        .map(|u| u.as_u64())
                        .collect();
                    let request = SessionRunRequest {
                        session_id: id.clone(),
                        times: sample_points.clone(),
                    };
                    let archive_key = build_session_run_key(id.clone(), sample_points.clone());

                    // have we sampled the times?
                    let processed_result = get_run_result(
                        archive,
                        "Partition".to_string(),
                        archive_key,
                        request.into(),
                    )?;

                    for i in 0..(ctx.query_size.as_usize() - 1) {
                        // get the i'th time in query array
                        let time = ctx.query_array.get(i).ok_or(Error::from(
                            ErrorKind::InvalidContractState(format!(
                                "could not find element {} in query array",
                                i
                            )),
                        ))?;
                        // get (i + 1)'th time in query array
                        let next_time = ctx.query_array.get(i + 1).ok_or(Error::from(
                            ErrorKind::InvalidContractState(format!(
                                "could not find element {} in query array",
                                i + 1
                            )),
                        ))?;
                        // get the (i + 1)'th hash in hash array
                        let claimed_hash = &ctx.hash_array.get(i + 1).ok_or(Error::from(
                            ErrorKind::InvalidContractState(format!(
                                "could not find element {} in hash array",
                                i + 1
                            )),
                        ))?;

                        // have we sampled that specific time?
                        let hash = processed_result.hashes.get(i + 1).unwrap();

                        if hash != *claimed_hash {
                            // do we need another partition?
                            if next_time.as_u64() - time.as_u64() > 1 {
                                // submit the relevant query
                                info!("Making Query for Partition (index: {})", instance.index);
                                let request = TransactionRequest {
                                    contract_name: None, // Name not needed, is concern
                                    concern: instance.concern.clone(),
                                    value: U256::from(0),
                                    function: "makeQuery".into(),
                                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                    // improve these types by letting the
                                    // dapp submit ethereum_types and convert
                                    // them inside the transaction manager
                                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                    data: vec![
                                        Token::Uint(instance.index),
                                        Token::Uint(U256::from(i)),
                                        Token::Uint(*time),
                                        Token::Uint(*next_time),
                                    ],
                                    gas: None,
                                    strategy: transaction::Strategy::Simplest,
                                };
                                return Ok(Reaction::Transaction(request));
                            } else {
                                // submit divergence time
                                info!(
                                    "Divergence found for Partition (index: {}, time: {})",
                                    instance.index, *time
                                );
                                let request = TransactionRequest {
                                    contract_name: None, // Name not needed, is concern
                                    concern: instance.concern.clone(),
                                    value: U256::from(0),
                                    function: "presentDivergence".into(),
                                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                    // improve these types by letting the
                                    // dapp submit ethereum_types and convert
                                    // them inside the transaction manager
                                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                    data: vec![Token::Uint(instance.index), Token::Uint(*time)],
                                    gas: None,
                                    strategy: transaction::Strategy::Simplest,
                                };
                                return Ok(Reaction::Transaction(request));
                            }
                        }
                    }
                    // no disagreement found. important bug!!!!
                    error!("bug found: no disagreement in dispute {:?}!!!", instance);
                    return Err(Error::from(format!("no disagreement in dispute")));
                }
                "WaitingHashes" => {
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
        }
    }

    fn get_pretty_instance(
        instance: &state::Instance,
        archive: &Archive,
        _machine_id: &String,
    ) -> Result<state::Instance> {
        // get context (state) of the partition instance
        let parsed: PartitionCtxParsed =
            serde_json::from_str(&instance.json_data).chain_err(|| {
                format!(
                    "Could not parse partition instance json_data: {}",
                    &instance.json_data
                )
            })?;
        let ctx: PartitionCtx = parsed.into();
        let json_data = serde_json::to_string(&ctx).unwrap();
        // get context (state) of the sub instances

        let pretty_sub_instances: Vec<Box<state::Instance>> = vec![];

        let pretty_instance = state::Instance {
            name: "Partition".to_string(),
            concern: instance.concern.clone(),
            index: instance.index,
            service_status: archive.get_service("Partition".into()),
            json_data: json_data,
            sub_instances: pretty_sub_instances,
        };

        return Ok(pretty_instance);
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use dispatcher::dapp::Reaction;
    use emulator_service::{SessionRunResponse, SessionRunResponseOneOf, SessionRunResult};
    use ethereum_types::H160;
    extern crate serde;

    pub fn build_state_json_data(
        current_state: &str,
        deadline: Option<&str>,
        hash_array: Option<Vec<&str>>,
        query_array: Option<Vec<&str>>,
        query_size: Option<&str>,
    ) -> String {
        let _deadline = deadline.unwrap_or("0x0");
        let _hash_array = hash_array.unwrap_or(vec![
            "0xd17a2e4b0ee0d6d6b6a034fa0b7307dd87ab1e7485fcb98496f5973e693a4269",
        ]);
        let _query_array = query_array.unwrap_or(vec!["0x1", "0x2", "0x3"]);
        let _query_size = query_size.unwrap_or("0x0");
        let data = serde_json::json!([
        {"name": "challenger",
        "value": "0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818",
        "type": "address"},

        {"name": "claimer",
        "value": "0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020",
        "type": "address"},

        {"name": "queryArray",
        "value": _query_array,
        "type": "uint256[]"},

        {"name": "submittedArray",
        "value": [true, false],
        "type": "bool[]"},

        {"name": "hashArray",
        "value": _hash_array,
        "type": "bytes"},

        {"name": "currentState",
        "value": current_state,
        "type": "bytes"},

        {"name": "response",
        "value": ["0x0",_query_size,_deadline,"0x0"],
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
    fn it_should_create_pctx_from_pctx_parsed() {
        let data = build_state_json_data("0x48656c6c6f20576f726c6421", None, None, None, None);

        // "48656c6c6f20776f726c6421", 0x48656c6c6f20576f726c6421
        let p: PartitionCtxParsed = serde_json::from_str(&data).unwrap();

        let parsed = PartitionCtx::from(p);
        assert_eq!(
            parsed.challenger,
            hash_from_string::<H160>("\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"")
        );
        assert_eq!(
            parsed.claimer,
            hash_from_string::<H160>("\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020\"")
        );
        assert_eq!(
            parsed.query_array,
            [U256::from(1), U256::from(2), U256::from(3)]
        );
        assert_eq!(parsed.submitted_array, [true, false]);
        assert_eq!(
            parsed.hash_array,
            [hash_from_string::<H256>(
                "\"0xd17a2e4b0ee0d6d6b6a034fa0b7307dd87ab1e7485fcb98496f5973e693a4269\""
            )]
        );
        assert_eq!(parsed.current_state, "Hello World!");
        assert_eq!(parsed.final_time, U256::from(0));
        assert_eq!(parsed.query_size, U256::from(0));
        assert_eq!(parsed.deadline, U256::from(0));
        assert_eq!(parsed.divergence_time, U256::from(0));
    }
    #[test]
    #[should_panic(expected = "User is neither claimer nor challenger")]
    fn it_should_be_idle() {
        let current_state = "0x4368616c6c656e676572576f6e"; // ChallengerWon,
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23945030\"",
            ),
        };
        let default_status = build_service_status();

        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_state_json_data(current_state, None, None, None, None),
            sub_instances,
        };
        {
            // ChallengerWon
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            // ClaimerWon
            let current_state = "0x436c61696d6572576f6e"; // ClaimerWon
            state_instance.json_data = build_state_json_data(current_state, None, None, None, None);
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            // DivergenceFound
            let current_state = "0x446976657267656e6365466f756e64"; // DivergenceFound
            state_instance.json_data = build_state_json_data(current_state, None, None, None, None);
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            // Hello World! // it should not work so it will panic
            let current_state = "0x48656c6c6f20576f726c6421"; // Hello World!
            state_instance.json_data = build_state_json_data(current_state, None, None, None, None);
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
    }

    #[test]
    #[should_panic(expected = "Unknown current state Unknown")]
    fn it_should_panic_role_claimer_unkown_state() {
        let current_state = "0x556e6b6e6f776e"; // Unknown,
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020\"",
            ), // claimer
        };
        let default_status = build_service_status();

        let state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_state_json_data(current_state, None, None, None, None),
            sub_instances,
        };
        let result = Partition::react(&state_instance, &archive, &None, &machine_id);
        assert!(matches!(result.unwrap(), Reaction::Idle));
    }

    #[test]
    #[should_panic(expected = "Unknown current state Unknown")]
    fn it_should_panic_role_challenger_unkown_state() {
        let current_state = "0x556e6b6e6f776e"; // Unknown,
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ), // challenger
        };
        let default_status = build_service_status();

        let state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_state_json_data(current_state, None, None, None, None),
            sub_instances,
        };
        let result = Partition::react(&state_instance, &archive, &None, &machine_id);
        assert!(matches!(result.unwrap(), Reaction::Idle));
    }
    #[test]
    fn it_should_call_win_by_deadline_as_claimer() {
        let current_state = "0x57616974696e675175657279"; // WaitingQuery
        let deadline = "0x1fffffffffffff";
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020\"",
            ), // claimer
        };
        let default_status = build_service_status();

        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_state_json_data(
                current_state,
                Option::from(deadline),
                None,
                None,
                None,
            ),
            sub_instances,
        };
        {
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            state_instance.json_data = build_state_json_data(current_state, None, None, None, None);
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
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
    }

    #[test]
    fn it_should_call_win_by_deadline_as_challenger() {
        let current_state = "0x57616974696e67486173686573"; // WaitingHashes
        let deadline = "0x1fffffffffffff";
        let machine_id = String::from("Machine000");
        let archive = Archive::new().unwrap();
        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ), // challenger
        };
        let default_status = build_service_status();
        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_state_json_data(
                current_state,
                Option::from(deadline),
                None,
                None,
                None,
            ),
            sub_instances,
        };
        {
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            state_instance.json_data = build_state_json_data(current_state, None, None, None, None);
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
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
    }
    #[test]
    #[should_panic(expected = "no disagreement in dispute")]
    fn it_should_make_tx_as_challenger() {
        let current_state = "0x57616974696e675175657279"; // WaitingQuery
        let machine_id = String::from("Machine000");
        let mut archive = Archive::new().unwrap();
        let bin: Vec<u8> = SessionRunResponse {
            one_of: SessionRunResponseOneOf::RunResult(SessionRunResult {
                hashes: vec![H256::zero(), H256::zero(), H256::zero()],
            }),
        }
        .into();

        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ), // challenger
        };
        let default_status = build_service_status();

        let mut state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: String::from(""),
            sub_instances,
        };

        let hash_array = vec![
            "0xd17a2e4b0ee0d6d6b6a034fa0b7307dd87ab1e7485fcb98496f5973e693a4270",
            "0xd17a2e4b0ee0d6d6b6a034fa0b7307dd87ab1e7485fcb98496f5973e693a4271",
            "0xd17a2e4b0ee0d6d6b6a034fa0b7307dd87ab1e7485fcb98496f5973e693a4272",
        ];
        let deadline = "0x1fffffffffffff";
        let query_size = "0x3";

        {
            // "makeQuery" transaction to key partitioning in search of divergence
            let query_array = vec!["0x1", "0x200", "0x3000"];
            let query_array_as_u64: Vec<u64> = vec![1, 512, 12288];

            let key = build_session_run_key(machine_id.clone(), query_array_as_u64);
            archive.insert_response(key, Ok(bin.clone()));

            state_instance.json_data = build_state_json_data(
                current_state,
                Option::from(deadline),
                Option::from(hash_array.clone()),
                Option::from(query_array),
                Option::from(query_size),
            );
            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "makeQuery");
            } else {
                panic!("Only transaction");
            }
        }

        {
            // "presentDivergence" transaction to end partition process
            // Re-create input to update values for query_array            let mut archive = Archive::new().unwrap();
            let query_array = vec!["0x1", "0x2", "0x3000"];
            let query_array_as_u64: Vec<u64> = vec![1, 2, 12288];
            let key = build_session_run_key(machine_id.clone(), query_array_as_u64);
            archive.insert_response(key, Ok(bin));
            state_instance.json_data = build_state_json_data(
                current_state,
                Option::from(deadline),
                Option::from(hash_array),
                Option::from(query_array),
                Option::from(query_size),
            );

            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "presentDivergence");
            } else {
                panic!("Only transaction");
            }
        }

        {
            // "error" no disagreement found
            let query_array = vec!["0x1", "0x2", "0x3000"];
            let zero_hash = "0x0000000000000000000000000000000000000000000000000000000000000000";
            let hash_array = vec![zero_hash, zero_hash, zero_hash];
            state_instance.json_data = build_state_json_data(
                current_state,
                Option::from(deadline),
                Option::from(hash_array),
                Option::from(query_array),
                Option::from(query_size),
            );

            let result = Partition::react(&state_instance, &archive, &None, &machine_id);
            let mut reaction = result.unwrap();
            panic!("Test should have failed already");
        }
    }
    #[test]
    fn it_should_make_tx_as_claimer() {
        let current_state = "0x57616974696e67486173686573"; // WaitingHashes
        let machine_id = String::from("Machine000");
        let mut archive = Archive::new().unwrap();
        let bin: Vec<u8> = SessionRunResponse {
            one_of: SessionRunResponseOneOf::RunResult(SessionRunResult {
                hashes: vec![H256::zero(), H256::zero(), H256::zero()],
            }),
        }
        .into();

        let deadline = "0x1fffffffffffff";
        let query_size = "0x3";
        let query_array = vec!["0x1", "0x200", "0x3000"];
        let query_array_as_u64: Vec<u64> = vec![1, 512, 12288];
        let key = build_session_run_key(machine_id.clone(), query_array_as_u64);
        archive.insert_response(key, Ok(bin));

        let hash_array = vec![
            "0xd17a2e4b0ee0d6d6b6a034fa0b7307dd87ab1e7485fcb98496f5973e693a4270",
            "0xd17a2e4b0ee0d6d6b6a034fa0b7307dd87ab1e7485fcb98496f5973e693a4271",
            "0xd17a2e4b0ee0d6d6b6a034fa0b7307dd87ab1e7485fcb98496f5973e693a4272",
        ];

        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23942020\"",
            ), // claimer
        };
        let default_status = build_service_status();

        let state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_state_json_data(
                current_state,
                Option::from(deadline),
                Option::from(hash_array),
                Option::from(query_array),
                Option::from(query_size),
            ),
            sub_instances,
        };

        let result = Partition::react(&state_instance, &archive, &None, &machine_id);
        let mut reaction = result.unwrap_or_else(|err| {
            std::process::exit(1);
        });
        assert!(matches!(
            &reaction,
            Reaction::Transaction(TransactionRequest)
        ));
        if let Reaction::Transaction(ref mut transaction) = reaction {
            assert_eq!(transaction.concern, concern);
            assert_eq!(transaction.function, "replyQuery");
        } else {
            panic!("Only transaction");
        }
    }
    
    #[test]
    fn it_should_get_pretty_instance_correctly() {
        let machine_id = String::from("Machine000");
        let current_state = "0x4368616c6c656e676572576f6e"; // ChallengerWon,
        let default_status = build_service_status();
        let sub_instances: Vec<Box<state::Instance>> = vec![];
        let archive = Archive::new().unwrap();
        let concern = configuration::Concern {
            contract_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
            user_address: hash_from_string::<H160>(
                "\"0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818\"",
            ),
        };

        let state_instance = state::Instance {
            name: "".to_string(),
            concern,
            index: U256::from(0),
            service_status: default_status,
            json_data: build_state_json_data(current_state, None, None, None, None),
            sub_instances,
        };

        let result = Partition::get_pretty_instance(&state_instance, &archive, &machine_id).unwrap();
        assert_eq!("Partition", result.name);
        assert_eq!(concern, result.concern);
        assert_eq!(state_instance.index, result.index);
        assert_eq!(0, result.sub_instances.len());
        let pretty_json: serde_json::value::Value = serde_json::from_str(&result.json_data).unwrap();
        assert!(pretty_json.is_object());
        assert_eq!(serde_json::json!("0x2dB2FBbF7DAC83b3883F0E4fCB58ba7f23941818".to_lowercase()), pretty_json["challenger"]);
        assert_eq!(serde_json::json!("0x0"), pretty_json["query_size"]);
    }
}

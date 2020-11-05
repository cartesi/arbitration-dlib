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

use super::build_session_step_key;
use super::dispatcher::{AddressField, Bytes32Field, String32Field, U256Field};
use super::dispatcher::{Archive, DApp, Reaction};
use super::error::Result;
use super::error::*;
use super::ethabi::Token;
use super::ethereum_types::{Address, H256, U256};
use super::transaction::TransactionRequest;
use super::{
    AccessType, SessionStepRequest, SessionStepResponse, EMULATOR_METHOD_STEP,
    EMULATOR_SERVICE_NAME,
};

pub struct MM();

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// these two structs and the From trait below shuld be
// obtained from a simple derive
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#[derive(Serialize, Deserialize)]
pub struct MMCtxParsed(
    pub AddressField,  // provider
    pub Bytes32Field,  // initialHash
    pub Bytes32Field,  // newHash
    pub U256Field,     // historyLength
    pub String32Field, // currentState
);

#[derive(Serialize, Debug)]
pub struct MMCtx {
    pub provider: Address,
    pub initial_hash: H256,
    pub final_hash: H256,
    pub history_length: U256,
    pub current_state: String,
}

#[derive(Default)]
pub struct MMParams {
    pub machine_id: String,
    pub divergence_time: U256,
}

impl From<MMCtxParsed> for MMCtx {
    fn from(parsed: MMCtxParsed) -> MMCtx {
        MMCtx {
            provider: parsed.0.value,
            initial_hash: parsed.1.value,
            final_hash: parsed.2.value,
            history_length: parsed.3.value,
            current_state: parsed.4.value,
        }
    }
}

impl DApp<MMParams> for MM {
    fn react(
        instance: &state::Instance,
        archive: &Archive,
        _post_payload: &Option<String>,
        params: &MMParams,
    ) -> Result<Reaction> {
        let parsed: MMCtxParsed = serde_json::from_str(&instance.json_data).chain_err(|| {
            format!(
                "Could not parse mm instance json_data: {}",
                &instance.json_data
            )
        })?;
        let ctx: MMCtx = parsed.into();

        trace!("Context for mm {:?}", ctx);

        // should not happen as it indicates an innactive instance,
        // but it is possible that the blockchain state changed between queries
        match ctx.current_state.as_ref() {
            "FinishedReplay" => {
                return Ok(Reaction::Idle);
            }
            _ => {}
        };

        match ctx.current_state.as_ref() {
            "WaitingProofs" => {
                // machine id
                let id = params.machine_id.clone();
                trace!("Calculating step of machine {}", id);
                let request = SessionStepRequest {
                    session_id: id.clone(),
                    time: params.divergence_time.as_u64(),
                };
                let archive_key =
                    build_session_step_key(id.clone(), params.divergence_time.to_string());

                // have we sampled the divergence time?
                let processed_response: SessionStepResponse = archive
                    .get_response(
                        EMULATOR_SERVICE_NAME.to_string(),
                        archive_key.clone(),
                        EMULATOR_METHOD_STEP.to_string(),
                        request.into(),
                    )?
                    .into();

                let step_log = processed_response.log;
                // if all proofs have been inserted, finish proof phase
                if ctx.history_length.as_usize() >= step_log.len() {
                    info!("Finishing Proof phase for MM (index: {})", instance.index);
                    let request = TransactionRequest {
                        contract_name: None, // Name not needed, is concern
                        concern: instance.concern.clone(),
                        value: U256::from(0),
                        function: "finishProofPhase".into(),
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

                // otherwise, submit one more proof step
                let access = (&step_log[ctx.history_length.as_usize()]).clone();
                let mut siblings: Vec<_> = access
                    .proof
                    .sibling_hashes
                    .into_iter()
                    .map(|hash| Token::FixedBytes(hash.0.to_vec()))
                    .collect();
                trace!("Size of siblings: {}", siblings.len());
                // !!!!! This should not be necessary, !!!!!!!
                // !!!!! the emulator should do it     !!!!!!!
                siblings.reverse();
                match access.field_type {
                    AccessType::Read => {
                        let request = TransactionRequest {
                            contract_name: None, // Name not needed, is concern
                            concern: instance.concern.clone(),
                            value: U256::from(0),
                            function: "proveRead".into(),
                            // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                            // improve these types by letting the
                            // dapp submit ethereum_types and convert
                            // them inside the transaction manager
                            // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                            data: vec![
                                Token::Uint(instance.index),
                                Token::Uint(U256::from(access.address)),
                                Token::FixedBytes(access.value_read.to_vec()),
                                Token::Array(siblings),
                            ],
                            gas: None,
                            strategy: transaction::Strategy::Simplest,
                        };
                        return Ok(Reaction::Transaction(request));
                    }
                    AccessType::Write => {
                        let request = TransactionRequest {
                            contract_name: None, // Name not needed, is concern
                            concern: instance.concern.clone(),
                            value: U256::from(0),
                            function: "proveWrite".into(),
                            // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                            // improve these types by letting the
                            // dapp submit ethereum_types and convert
                            // them inside the transaction manager
                            // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                            data: vec![
                                Token::Uint(instance.index),
                                Token::Uint(U256::from(access.address)),
                                Token::FixedBytes(access.value_read.to_vec()),
                                Token::FixedBytes(access.value_written.to_vec()),
                                Token::Array(siblings),
                            ],
                            gas: None,
                            strategy: transaction::Strategy::Simplest,
                        };
                        return Ok(Reaction::Transaction(request));
                    }
                }
            }
            _ => {}
        }

        return Ok(Reaction::Idle);
    }

    fn get_pretty_instance(
        instance: &state::Instance,
        archive: &Archive,
        _params: &MMParams,
    ) -> Result<state::Instance> {
        // get context (state) of the mm instance
        let parsed: MMCtxParsed = serde_json::from_str(&instance.json_data).chain_err(|| {
            format!(
                "Could not parse mm instance json_data: {}",
                &instance.json_data
            )
        })?;
        let ctx: MMCtx = parsed.into();
        let json_data = serde_json::to_string(&ctx).unwrap();

        // get context (state) of the sub instances

        let pretty_sub_instances: Vec<Box<state::Instance>> = vec![];

        let pretty_instance = state::Instance {
            name: "MM".to_string(),
            concern: instance.concern.clone(),
            index: instance.index,
            service_status: archive.get_service("MM".into()),
            json_data: json_data,
            sub_instances: pretty_sub_instances,
        };

        return Ok(pretty_instance);
    }
}
#[cfg(test)]
pub mod tests {

    use super::*;
    use emulator_service;
    use tests::{
        build_concern, build_state, encode, CONTRACTADDR, MACHINEID, UNKNOWNSTATE,
    };

    pub fn build_mm_state_json_data(current_state: &str, history_length: Option<&str>) -> String {
        let _history_length = history_length.unwrap_or("0x0");
        let data = serde_json::json!([
        {"name": "provider",
        "value": CONTRACTADDR,
        "type": "address"},

        {"name": "initial_hash",
        "value": "0xa70817cd86277772e8f71cfe28d32da866b05f981d80e4d17eae915321930000",
        "type": "bytes32"},

        {"name": "new_hash",
        "value": "0xa70817cd86277772e8f71cfe28d32da866b05f981d80e4d17eae915321930000",
        "type": "bytes32"},

        {"name": "historyLength",
        "value": _history_length,
        "type": "uint256"},

        {"name": "currentState",
        "value": current_state,
        "type": "bytes"}

        ]);
        return String::from(serde_json::to_string(&data).unwrap());
    }

    #[test]
    fn it_should_be_idle() {
        let divergence_time = U256::from("200");
        let mm_params = MMParams {
            machine_id: String::from(MACHINEID),
            divergence_time,
        };
        let current_state = encode("FinishedReplay"); // FinishedReplay,
        let archive = Archive::new().unwrap();
        // Through out these tests we will be using CONTRACTADDR as the user_address since 
        //at this point it will not interfere with the results and we want to capture changes
        //that affect this behaviour
        let concern = build_concern(CONTRACTADDR);

        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_mm_state_json_data(current_state.as_str(), None);

        {
            // FinishedReplay
            let result = MM::react(&state_instance, &archive, &None, &mm_params);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
        {
            let current_state = encode(UNKNOWNSTATE);
            state_instance.json_data = build_mm_state_json_data(current_state.as_str(), None);
            let result = MM::react(&state_instance, &archive, &None, &mm_params);
            assert!(matches!(result.unwrap(), Reaction::Idle));
        }
    }

    #[test]
    fn it_should_work_waiting_proofs_correclty() {
        let divergence_time = U256::from("200");
        let mm_params = MMParams {
            machine_id: String::from(MACHINEID),
            divergence_time,
        };
        let current_state = encode("WaitingProofs");

        let mut archive = Archive::new().unwrap();
        let proof = emulator_service::Proof {
            address: 100,
            log2_size: 2,
            target_hash: H256::zero(),
            root_hash: H256::zero(),
            sibling_hashes: vec![H256::zero(), H256::zero(), H256::zero(), H256::zero()],
        };
        let mut access = emulator_service::Access {
            field_type: emulator_service::AccessType::Read,
            address: 100,
            value_read: [0, 1, 2, 3, 4, 5, 6, 7],
            value_written: [0, 1, 2, 3, 4, 5, 6, 7],
            proof,
        };
        let bin: Vec<u8> = SessionStepResponse {
            log: vec![access.clone()],
        }
        .into();
        let archive_key = build_session_step_key(
            String::from(MACHINEID),
            mm_params.divergence_time.to_string(),
        );
        let concern = build_concern(CONTRACTADDR);

        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_mm_state_json_data(current_state.as_str(), None);

        {
            //proveRead
            archive.insert_response(archive_key.clone(), Ok(bin.clone()));
            let result = MM::react(&state_instance, &archive, &None, &mm_params);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            //@TODO test all fields of the reaction
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "proveRead");
            } else {
                panic!("Only transaction");
            }
        }
        {
            //proveWrite
            access.field_type = emulator_service::AccessType::Write;
            let bin: Vec<u8> = SessionStepResponse {
                log: vec![access.clone()],
            }
            .into();
            archive.insert_response(archive_key, Ok(bin.clone()));
            let result = MM::react(&state_instance, &archive, &None, &mm_params);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            //@TODO test all fields of the reaction
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "proveWrite");
            } else {
                panic!("Only transaction");
            }
        }
        {
            // Finish Proof
            state_instance.json_data =
                build_mm_state_json_data(current_state.as_str(), Option::from("0x10"));
            let result = MM::react(&state_instance, &archive, &None, &mm_params);
            let mut reaction = result.unwrap();
            assert!(matches!(
                &reaction,
                Reaction::Transaction(TransactionRequest)
            ));
            //@TODO test all fields of the reaction
            if let Reaction::Transaction(ref mut transaction) = reaction {
                assert_eq!(transaction.concern, concern);
                assert_eq!(transaction.function, "finishProofPhase");
            } else {
                panic!("Only transaction");
            }
        }
    }

    #[test]
    fn it_should_get_pretty_instance_correctly() {
        let divergence_time = U256::from("200");
        let mm_params = MMParams {
            machine_id: String::from(MACHINEID),
            divergence_time,
        };
        let current_state = encode("ChallengerWon"); // ChallengerWon,
        let archive = Archive::new().unwrap();
        let concern = build_concern(CONTRACTADDR);

        let mut state_instance = build_state(concern, None);
        state_instance.json_data = build_mm_state_json_data(current_state.as_str(), None);

        let result = MM::get_pretty_instance(&state_instance, &archive, &mm_params).unwrap();
        assert_eq!("MM", result.name);
        assert_eq!(concern, result.concern);
        assert_eq!(state_instance.index, result.index);
        assert_eq!(0, result.sub_instances.len());
        let pretty_json: serde_json::value::Value =
            serde_json::from_str(&result.json_data).unwrap();
        assert!(pretty_json.is_object());
        assert_eq!(
            serde_json::json!(CONTRACTADDR.to_lowercase()),
            pretty_json["provider"]
        );
        assert_eq!(serde_json::json!("0x0"), pretty_json["history_length"]);
        assert_eq!(
            serde_json::json!("ChallengerWon"),
            pretty_json["current_state"]
        );
    }
}

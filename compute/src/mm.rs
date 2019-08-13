// Arbritration DLib is the combination of the on-chain protocol and off-chain
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


use super::build_machine_id;
use super::dispatcher::{AddressField, Bytes32Field, String32Field, U256Field};
use super::dispatcher::{Archive, DApp, Reaction, SessionStepRequest};
use super::emulator::AccessOperation;
use super::error::Result;
use super::error::*;
use super::ethabi::Token;
use super::ethereum_types::{Address, H256, U256};
use super::transaction::TransactionRequest;

pub struct MM();

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// these two structs and the From trait below shuld be
// obtained from a simple derive
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#[derive(Serialize, Deserialize)]
pub struct MMCtxParsed(
    pub AddressField,  // provider
    pub AddressField,  // client
    pub Bytes32Field,  // initialHash
    pub Bytes32Field,  // newHash
    pub U256Field,     // historyLength
    pub String32Field, // currentState
);

#[derive(Debug)]
pub struct MMCtx {
    pub provider: Address,
    pub client: Address,
    pub initial_hash: H256,
    pub final_hash: H256,
    pub history_length: U256,
    pub current_state: String,
}

impl From<MMCtxParsed> for MMCtx {
    fn from(parsed: MMCtxParsed) -> MMCtx {
        MMCtx {
            provider: parsed.0.value,
            client: parsed.1.value,
            initial_hash: parsed.2.value,
            final_hash: parsed.3.value,
            history_length: parsed.4.value,
            current_state: parsed.5.value,
        }
    }
}

impl DApp<U256> for MM {
    fn react(
        instance: &state::Instance,
        archive: &Archive,
        divergence_time: &U256,
    ) -> Result<Reaction> {
        let parsed: MMCtxParsed = serde_json::from_str(&instance.json_data)
            .chain_err(|| {
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
                let id = build_machine_id(
                    instance.index,
                    &instance.concern.contract_address,
                );
                trace!("Calculating step of machine {}", id);
                // have we steped this machine yet?
                if let Some(samples) = archive.get(&id) {
                    // take the step samples (not the run samples)
                    let step_samples = &samples.step;
                    // have we sampled the divergence time?
                    if let Some(step_log) = step_samples.get(divergence_time) {
                        // if all proofs have been inserted, finish proof phase
                        if ctx.history_length.as_usize() >= step_log.len() {
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "finishProofPhase".into(),
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                // improve these types by letting the
                                // dapp submit ethereum_types and convert
                                // them inside the transaction manager
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                data: vec![Token::Uint(instance.index)],
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }

                        // otherwise, submit one more proof step
                        let access =
                            (&step_log[ctx.history_length.as_usize()]).clone();
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
                        match access.operation {
                            AccessOperation::Read => {
                                let request = TransactionRequest {
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
                                        Token::FixedBytes(
                                            access.value_read.to_vec()
                                        ),
                                        Token::Array(siblings),
                                    ],
                                    strategy: transaction::Strategy::Simplest,
                                };
                                return Ok(Reaction::Transaction(request));
                            }
                            AccessOperation::Write => {
                                let request = TransactionRequest {
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
                                        Token::FixedBytes(
                                            access.value_read.to_vec(),
                                        ),
                                        Token::FixedBytes(
                                            access.value_written.to_vec(),
                                        ),
                                        Token::Array(siblings),
                                    ],
                                    strategy: transaction::Strategy::Simplest,
                                };
                                return Ok(Reaction::Transaction(request));
                            }
                        }
                    }
                };
                // divergence step log has not been calculated yet, request it
                return Ok(Reaction::Step(SessionStepRequest {
                    session_id: id,
                    time: divergence_time.as_u64(),
                }));
            }
            _ => {}
        }

        return Ok(Reaction::Idle);
    }
}

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
use super::configuration::Concern;
use super::dispatcher::{AddressField, Bytes32Field, String32Field, U256Field};
use super::dispatcher::{Archive, DApp, Reaction, SessionRunRequest};
use super::error::Result;
use super::error::*;
use super::ethabi::Token;
use super::ethereum_types::{Address, H256, U256};
use super::transaction;
use super::transaction::TransactionRequest;
use super::{Role, VG};
use vg::{VGCtx, VGCtxParsed};

use std::time::{SystemTime, UNIX_EPOCH};

pub struct Compute();

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// these two structs and the From trait below shuld be
// obtained from a simple derive
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#[derive(Serialize, Deserialize)]
struct ComputeCtxParsed(
    AddressField,  // challenger
    AddressField,  // claimer
    U256Field,     // roundDuration
    U256Field,     // timeOfLastMove
    AddressField,  // machine
    Bytes32Field,  // initialHash
    U256Field,     // finalTime
    Bytes32Field,  // claimedFinalHash
    String32Field, // currentState
);

#[derive(Debug)]
struct ComputeCtx {
    challenger: Address,
    claimer: Address,
    round_duration: U256,
    time_of_last_move: U256,
    machine: Address,
    initial_hash: H256,
    final_time: U256,
    claimed_final_hash: H256,
    current_state: String,
}

impl From<ComputeCtxParsed> for ComputeCtx {
    fn from(parsed: ComputeCtxParsed) -> ComputeCtx {
        ComputeCtx {
            challenger: parsed.0.value,
            claimer: parsed.1.value,
            round_duration: parsed.2.value,
            time_of_last_move: parsed.3.value,
            machine: parsed.4.value,
            initial_hash: parsed.5.value,
            final_time: parsed.6.value,
            claimed_final_hash: parsed.7.value,
            current_state: parsed.8.value,
        }
    }
}

impl DApp<()> for Compute {
    /// React to the compute contract, submitting solutions, confirming
    /// or challenging them when appropriate
    fn react(
        instance: &state::Instance,
        archive: &Archive,
        _: &(),
    ) -> Result<Reaction> {
        // get context (state) of the compute instance
        let parsed: ComputeCtxParsed =
            serde_json::from_str(&instance.json_data).chain_err(|| {
                format!(
                    "Could not parse compute instance json_data: {}",
                    &instance.json_data
                )
            })?;
        let ctx: ComputeCtx = parsed.into();
        trace!("Context for compute (index {}) {:?}", instance.index, ctx);

        // these states should not occur as they indicate an innactive instance,
        // but it is possible that the blockchain state changed between queries
        match ctx.current_state.as_ref() {
            "ClaimerMissedDeadline"
            | "ChallengerWon"
            | "ClaimerWon"
            | "ConsensusResult" => {
                return Ok(Reaction::Idle);
            }
            _ => {}
        };

        // if we reach this code, the instance is active, get user's role
        let role = match instance.concern.user_address {
            cl if (cl == ctx.claimer) => Role::Claimer,
            ch if (ch == ctx.challenger) => Role::Challenger,
            _ => {
                return Err(Error::from(ErrorKind::InvalidContractState(
                    String::from("User is neither claimer nor challenger"),
                )));
            }
        };
        trace!("Role played (index {}) is: {:?}", instance.index, role);

        match role {
            Role::Claimer => match ctx.current_state.as_ref() {
                "WaitingConfirmation" => {
                    return win_by_deadline_or_idle(
                        &instance.concern,
                        instance.index,
                        ctx.time_of_last_move.as_u64(),
                        ctx.round_duration.as_u64(),
                    );
                }
                "WaitingClaim" => {
                    // machine id
                    let id = build_machine_id(
                        instance.index,
                        &instance.concern.contract_address,
                    );
                    trace!("Calculating final hash of machine {}", id);
                    // have we sampled this machine yet?
                    if let Some(samples) = archive.get(&id) {
                        // take the run samples (not the step samples)
                        let run_samples = &samples.run;
                        // have we sampled the final time?
                        if let Some(hash) = run_samples.get(&ctx.final_time) {
                            // if yes, submit the final hash
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "submitClaim".into(),
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                // improve these types by letting the
                                // dapp submit ethereum_types and convert
                                // them inside the transaction manager
                                // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                                data: vec![
                                    Token::Uint(instance.index),
                                    Token::FixedBytes(hash.0.to_vec()),
                                ],
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }
                    };
                    // final hash has not been calculated yet, request it
                    let sample_points: Vec<u64> =
                        vec![0, ctx.final_time.as_u64()];
                    return Ok(Reaction::Request(SessionRunRequest {
                        session_id: id,
                        times: sample_points,
                    }));
                }
                "WaitingChallenge" => {
                    // we inspect the verification contract
                    let vg_instance = instance.sub_instances.get(0).ok_or(
                        Error::from(ErrorKind::InvalidContractState(format!(
                            "There is no vg instance {}",
                            ctx.current_state
                        ))),
                    )?;
                    let vg_parsed: VGCtxParsed =
                        serde_json::from_str(&vg_instance.json_data)
                            .chain_err(|| {
                                format!(
                                    "Could not parse vg instance json_data: {}",
                                    &vg_instance.json_data
                                )
                            })?;
                    let vg_ctx: VGCtx = vg_parsed.into();

                    match vg_ctx.current_state.as_ref() {
                        "FinishedClaimerWon" => {
                            // claim victory in compute contract
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "winByVG".into(),
                                data: vec![Token::Uint(instance.index)],
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }
                        "FinishedChallengerWon" => {
                            error!("we lost a verification game {:?}", vg_ctx);
                            return Ok(Reaction::Idle);
                        }
                        _ => {
                            // verification game is still active,
                            // pass control to the appropriate dapp
                            return VG::react(vg_instance, archive, &());
                        }
                    }
                }
                _ => {
                    return Err(Error::from(ErrorKind::InvalidContractState(
                        format!("Unknown current state {}", ctx.current_state),
                    )));
                }
            },
            Role::Challenger => match ctx.current_state.as_ref() {
                "WaitingConfirmation" => {
                    // here goes the calculation of the final hash
                    // to check the claim and potentialy raise challenge
                    // machine id
                    let id = build_machine_id(
                        instance.index,
                        &instance.concern.contract_address,
                    );
                    trace!("Calculating final hash of machine {}", id);
                    // have we sampled this machine yet?
                    if let Some(samples) = archive.get(&id) {
                        let run_samples = &samples.run;
                        // have we sampled the final time?
                        if let Some(hash) = run_samples.get(&ctx.final_time) {
                            if hash == &ctx.claimed_final_hash {
                                info!(
                                    "Confirming final hash {:?} for {}",
                                    hash, id
                                );
                                let request = TransactionRequest {
                                    concern: instance.concern.clone(),
                                    value: U256::from(0),
                                    function: "confirm".into(),
                                    data: vec![Token::Uint(instance.index)],
                                    strategy: transaction::Strategy::Simplest,
                                };
                                return Ok(Reaction::Transaction(request));
                            } else {
                                warn!(
                                    "Disputing final hash {:?} != {} for {}",
                                    hash, ctx.claimed_final_hash, id
                                );
                                let request = TransactionRequest {
                                    concern: instance.concern.clone(),
                                    value: U256::from(0),
                                    function: "challenge".into(),
                                    data: vec![Token::Uint(instance.index)],
                                    strategy: transaction::Strategy::Simplest,
                                };

                                return Ok(Reaction::Transaction(request));
                            }
                        }
                    };
                    // final hash has not been calculated yet, request it
                    let sample_points: Vec<u64> =
                        vec![0, ctx.final_time.as_u64()];
                    return Ok(Reaction::Request(SessionRunRequest {
                        session_id: id,
                        times: sample_points,
                    }));
                }
                "WaitingClaim" => {
                    return win_by_deadline_or_idle(
                        &instance.concern,
                        instance.index,
                        ctx.time_of_last_move.as_u64(),
                        ctx.round_duration.as_u64(),
                    );
                }
                "WaitingChallenge" => {
                    // we inspect the verification contract
                    let vg_instance = instance.sub_instances.get(0).ok_or(
                        Error::from(ErrorKind::InvalidContractState(format!(
                            "There is no vg instance {}",
                            ctx.current_state
                        ))),
                    )?;
                    let vg_parsed: VGCtxParsed =
                        serde_json::from_str(&vg_instance.json_data)
                            .chain_err(|| {
                                format!(
                                    "Could not parse vg instance json_data: {}",
                                    &vg_instance.json_data
                                )
                            })?;
                    let vg_ctx: VGCtx = vg_parsed.into();

                    match vg_ctx.current_state.as_ref() {
                        "FinishedChallengerWon" => {
                            // claim victory in compute contract
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "winByVG".into(),
                                data: vec![Token::Uint(instance.index)],
                                strategy: transaction::Strategy::Simplest,
                            };
                            return Ok(Reaction::Transaction(request));
                        }
                        "FinishedClaimerWon" => {
                            error!("we lost a verification game {:?}", vg_ctx);
                            return Ok(Reaction::Idle);
                        }
                        _ => {
                            // verification game is still active,
                            // pass control to the appropriate dapp
                            return VG::react(vg_instance, archive, &());
                        }
                    }
                }
                _ => {
                    return Err(Error::from(ErrorKind::InvalidContractState(
                        format!("Unknown current state {}", ctx.current_state),
                    )));
                }
            },
        }
    }
}

pub fn win_by_deadline_or_idle(
    concern: &Concern,
    index: U256,
    time_of_last_move: u64,
    round_duration: u64,
) -> Result<Reaction> {
    let current_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .chain_err(|| "System time before UNIX_EPOCH")?
        .as_secs();

    // if other party missed the deadline
    if current_time > time_of_last_move + round_duration {
        let request = TransactionRequest {
            concern: concern.clone(),
            value: U256::from(0),
            function: "claimVictoryByTime".into(),
            data: vec![Token::Uint(index)],
            strategy: transaction::Strategy::Simplest,
        };
        return Ok(Reaction::Transaction(request));
    } else {
        // if not, then wait
        return Ok(Reaction::Idle);
    }
}

use super::dispatcher::{
    AddressField, Bytes32Field, String32Field, U256Array6,
};
use super::dispatcher::{Archive, DApp, Reaction};
use super::error::Result;
use super::error::*;
use super::ethabi::Token;
use super::ethereum_types::{Address, H256, U256};
use super::transaction::TransactionRequest;
use super::{Partition, Role, MM};
use compute::win_by_deadline_or_idle;
use mm::{MMCtx, MMCtxParsed};
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
    U256Array6,    // uint values: roundDuration
                   //              finalTime
                   //              timeOfLastMove
                   //              mmInstance
                   //              partitionInstance
                   //              divergenceTime
);

#[derive(Debug)]
pub struct VGCtx {
    pub challenger: Address,
    pub claimer: Address,
    pub machine: Address,
    pub initial_hash: H256,
    pub claimer_final_hash: H256,
    pub hash_before_divergence: H256,
    pub hash_after_divergence: H256,
    pub current_state: String,
    pub round_duration: U256,
    pub final_time: U256,
    pub time_of_last_move: U256,
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
            round_duration: parsed.8.value[0],
            final_time: parsed.8.value[1],
            time_of_last_move: parsed.8.value[2],
            mm_instance: parsed.8.value[3],
            partition_instance: parsed.8.value[4],
            divergence_time: parsed.8.value[5],
        }
    }
}

impl DApp<()> for VG {
    fn react(
        instance: &state::Instance,
        archive: &Archive,
        _: &(),
    ) -> Result<Reaction> {
        let parsed: VGCtxParsed = serde_json::from_str(&instance.json_data)
            .chain_err(|| {
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
                return Err(Error::from(ErrorKind::InvalidContractState(
                    String::from("User is neither claimer nor challenger"),
                )));
            }
        };
        trace!("Role played (index {}) is: {:?}", instance.index, role);

        match role {
            Role::Claimer => match ctx.current_state.as_ref() {
                "WaitPartition" => {
                    // get the partition instance to see if its is finished
                    let partition_instance =
                        instance.sub_instances.get(0).ok_or(Error::from(
                            ErrorKind::InvalidContractState(format!(
                                "There is no partition instance {}",
                                ctx.current_state
                            )),
                        ))?;

                    let partition_parsed: PartitionCtxParsed =
                        serde_json::from_str(&partition_instance.json_data)
                            .chain_err(|| {
                                format!(
                            "Could not parse partition instance json_data: {}",
                            &instance.json_data
                                )
                            })?;
                    let partition_ctx: PartitionCtx = partition_parsed.into();

                    match partition_ctx.current_state.as_ref() {
                        "ClaimerWon" => {
                            // claim victory by partition timeout
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "winByPartitionTimeout".into(),
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
                        "DivergenceFound" => {
                            // start the machine run challenge
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "startMachineRunChallenge".into(),
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
                        _ => {
                            // partition is still running,
                            // pass control to the partition dapp
                            return Partition::react(
                                partition_instance,
                                archive,
                                &(),
                            );
                        }
                    }
                }
                "WaitMemoryProveValues" => {
                    return win_by_deadline_or_idle(
                        &instance.concern,
                        instance.index,
                        ctx.time_of_last_move.as_u64(),
                        ctx.round_duration.as_u64(),
                    );
                }
                _ => {
                    return Err(Error::from(ErrorKind::InvalidContractState(
                        format!("Unknown current state {}", ctx.current_state),
                    )));
                }
            },
            Role::Challenger => match ctx.current_state.as_ref() {
                "WaitPartition" => {
                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    // deduplicate code with wait partition above
                    // not quite the same
                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    // get the partition instance to see if its is finished
                    let partition_instance =
                        instance.sub_instances.get(0).ok_or(Error::from(
                            ErrorKind::InvalidContractState(format!(
                                "There is no partition instance {}",
                                ctx.current_state
                            )),
                        ))?;

                    let partition_parsed: PartitionCtxParsed =
                        serde_json::from_str(&partition_instance.json_data)
                            .chain_err(|| {
                                format!(
                            "Could not parse partition instance json_data: {}",
                            &instance.json_data
                                )
                            })?;
                    let partition_ctx: PartitionCtx = partition_parsed.into();

                    match partition_ctx.current_state.as_ref() {
                        "ChallengerWon" => {
                            // claim victory by partition timeout
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "winByPartitionTimeout".into(),
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
                        "DivergenceFound" => {
                            // start the machine run challenge
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "startMachineRunChallenge".into(),
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
                        _ => {
                            // partition is still running,
                            // pass control to the partition dapp
                            return Partition::react(
                                partition_instance,
                                archive,
                                &(),
                            );
                        }
                    }
                }
                "WaitMemoryProveValues" => {
                    let mm_instance = instance.sub_instances.get(0).ok_or(
                        Error::from(ErrorKind::InvalidContractState(format!(
                            "There is no memory manager instance {}",
                            ctx.current_state
                        ))),
                    )?;

                    let mm_parsed: MMCtxParsed =
                        serde_json::from_str(&mm_instance.json_data)
                            .chain_err(|| {
                                format!(
                                    "Could not parse mm instance json_data: {}",
                                    &instance.json_data
                                )
                            })?;
                    let mm_ctx: MMCtx = mm_parsed.into();

                    match mm_ctx.current_state.as_ref() {
                        "WaitingProofs" => {
                            return MM::react(
                                mm_instance,
                                archive,
                                &ctx.divergence_time,
                            );
                        }
                        "WaitingReplay" => {
                            // start the machine run challenge
                            let request = TransactionRequest {
                                concern: instance.concern.clone(),
                                value: U256::from(0),
                                function: "settleVerificationGame".into(),
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
                    return Err(Error::from(ErrorKind::InvalidContractState(
                        format!("Unknown current state {}", ctx.current_state),
                    )));
                }
            },
        }
    }
}

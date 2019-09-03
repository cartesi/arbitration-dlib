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
use super::dispatcher::{AddressField, String32Field};
use super::dispatcher::{Archive, DApp, Reaction, NewSessionRequest};
use super::error::Result;
use super::error::*;
use super::ethabi::Token;
use super::transaction;
use super::transaction::TransactionRequest;
use super::ethereum_types::{Address, U256};
use super::Role;
use super::compute::{Compute, ComputeCtx, ComputeCtxParsed};

pub struct ArbitrationTest();

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// these two structs and the From trait below shuld be
// obtained from a simple derive
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#[derive(Serialize, Deserialize)]
struct ArbitrationTestCtxParsed(
    AddressField,  // challenger
    AddressField,  // claimer
    AddressField,  // compute
    String32Field, // currentState
);

#[derive(Debug)]
struct ArbitrationTestCtx {
    challenger: Address,
    claimer: Address,
    compute: Address,
    current_state: String,
}

impl From<ArbitrationTestCtxParsed> for ArbitrationTestCtx {
    fn from(parsed: ArbitrationTestCtxParsed) -> ArbitrationTestCtx {
        ArbitrationTestCtx {
            challenger: parsed.0.value,
            claimer: parsed.1.value,
            compute: parsed.2.value,
            current_state: parsed.3.value,
        }
    }
}

impl DApp<()> for ArbitrationTest {
    /// React to the arbitration test contract, active/inactive
    fn react(
        instance: &state::Instance,
        archive: &Archive,
        _: &(),
    ) -> Result<Reaction> {
        // get context (state) of the arbitration test instance
        let parsed: ArbitrationTestCtxParsed =
            serde_json::from_str(&instance.json_data).chain_err(|| {
                format!(
                    "Could not parse arbitration instance json_data: {}",
                    &instance.json_data
                )
            })?;
        let ctx: ArbitrationTestCtx = parsed.into();
        trace!("Context for arbitration (index {}) {:?}", instance.index, ctx);

        match ctx.current_state.as_ref() {
            "Finished" => {
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

        // machine id
        let id = build_machine_id(
            instance.index,
            &instance.concern.contract_address,
        );
        trace!("Calculating final hash of machine {}", id);
        // have we sampled this machine yet?
        if let Some(_samples) = archive.get(&id) {
            // we inspect the compute contract
            let compute_instance = instance.sub_instances.get(0).ok_or(
                Error::from(ErrorKind::InvalidContractState(format!(
                    "There is no compute instance {}",
                    ctx.current_state
                ))),
            )?;
            let compute_parsed: ComputeCtxParsed =
                serde_json::from_str(&compute_instance.json_data)
                    .chain_err(|| {
                        format!(
                            "Could not parse compute instance json_data: {}",
                            &compute_instance.json_data
                        )
                    })?;
            let compute_ctx: ComputeCtx = compute_parsed.into();

            match compute_ctx.current_state.as_ref() {
                "ClaimerMissedDeadline" |
                "ChallengerWon" |
                "ClaimerWon" |
                "ConsensusResult" => {
                    // claim Finished in arbitration test contract
                    let request = TransactionRequest {
                        concern: instance.concern.clone(),
                        value: U256::from(0),
                        function: "claimFinished".into(),
                        data: vec![Token::Uint(instance.index)],
                        strategy: transaction::Strategy::Simplest,
                    };
                    return Ok(Reaction::Transaction(request));
                }
                _ => {
                    // compute is still active,
                    // pass control to the appropriate dapp
                    return Compute::react(compute_instance, archive, &());
                }
            }
        }
        let new_session_request = NewSessionRequest {
            session_id: id,
            machine: emulator_interface::cartesi_base::MachineRequest::new()
        };
        return Ok(Reaction::NewSession(new_session_request));
    }
}

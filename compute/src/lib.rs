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

#![warn(unused_extern_crates)]
pub mod compute;
pub mod emulator_service;
pub mod mm;
pub mod partition;
pub mod vg;

extern crate configuration;
extern crate error;
extern crate grpc;

#[macro_use]
extern crate serde_derive;
#[macro_use]
extern crate log;
extern crate dispatcher;
extern crate emulator;
extern crate ethabi;
extern crate ethereum_types;
extern crate transaction;

pub use compute::{Compute, ComputeCtx, ComputeCtxParsed, win_by_deadline_or_idle};
pub use emulator::{cartesi_machine, machine_manager};
pub use emulator_service::{
    AccessOperation, NewSessionRequest, NewSessionResponse, SessionGetProofRequest,
    SessionGetProofResponse, SessionReadMemoryRequest, SessionReadMemoryResponse,
    SessionRunRequest, SessionRunResponse, SessionStepRequest, SessionStepResponse,
    SessionRunResponseOneOf, SessionRunResult, SessionWriteMemoryRequest,
    EMULATOR_METHOD_NEW, EMULATOR_METHOD_PROOF, EMULATOR_METHOD_WRITE,
    EMULATOR_METHOD_READ, EMULATOR_METHOD_RUN, EMULATOR_METHOD_STEP,
    EMULATOR_SERVICE_NAME, 
};
pub use mm::MM;
pub use partition::Partition;
pub use vg::{VGCtx, VGCtxParsed, VG};

#[derive(Debug)]
enum Role {
    Claimer,
    Challenger,
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// we need to have a proper way to construct machine ids.
// but this will only make real sense when we have the scripting
// language or some other means to construct a machine inside the
// blockchain.
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

pub fn build_session_run_key(id: String, times: Vec<u64>) -> String {
    return format!("{}_run_{:?}", id, times);
}

pub fn build_session_step_key(id: String, divergence_time: String) -> String {
    return format!("{}_step_{}", id, divergence_time);
}

pub fn build_session_read_key(id: String, time: u64, address: u64, length: u64) -> String {
    return format!("{}_read_{}_{}_{}", id, time, address, length);
}

pub fn build_session_write_key(id: String, time: u64, address: u64, data: Vec<u8>) -> String {
    return format!("{}_write_{}_{}_{:?}", id, time, address, data);
}

pub fn build_session_proof_key(id: String, time: u64, address: u64, log2_size: u64) -> String {
    return format!("{}_proof_{}_{}_{}", id, time, address, log2_size);
}

pub fn get_run_result(
    archive: &dispatcher::Archive,
    contract: String,
    key: String,
    request: Vec<u8>
) -> error::Result<SessionRunResult> {
    let processed_response: SessionRunResponse = archive
        .get_response(
            EMULATOR_SERVICE_NAME.to_string(),
            key.clone(),
            EMULATOR_METHOD_RUN.to_string(),
            request.clone()
        )?
        .into();
    
    match processed_response.one_of {
        SessionRunResponseOneOf::RunResult(s) => {
            Ok(s)
        },
        SessionRunResponseOneOf::RunProgress(p) => {
            error!("Fail to get machine run result, progress: {}", p.progress);
            Err(error::Error::from(error::ErrorKind::ServiceNeedsRetry(
                EMULATOR_SERVICE_NAME.to_string(),
                key,
                EMULATOR_METHOD_RUN.to_string(),
                request,
                contract,
                1,
                p.progress,
                "machine stil running".to_string()
            )))
        },
    }
}

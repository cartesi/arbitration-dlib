// Dispatcher provides the infrastructure to support the development of DApps,
// mediating the communication between on-chain and off-chain components.

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

//! A collection of types that represent the manager grpc interface
//! together with the conversion functions from the automatically
//! generated types.

use super::ethereum_types::H256;
use super::grpc::marshall::Marshaller;
use super::{cartesi_machine, machine_manager};

pub const EMULATOR_SERVICE_NAME: &'static str = "emulator";
pub const EMULATOR_METHOD_NEW: &'static str = "/CartesiMachineManager.MachineManager/NewSession";
pub const EMULATOR_METHOD_RUN: &'static str = "/CartesiMachineManager.MachineManager/SessionRun";
pub const EMULATOR_METHOD_STEP: &'static str = "/CartesiMachineManager.MachineManager/SessionStep";
pub const EMULATOR_METHOD_READ: &'static str =
    "/CartesiMachineManager.MachineManager/SessionReadMemory";
pub const EMULATOR_METHOD_WRITE: &'static str =
    "/CartesiMachineManager.MachineManager/SessionWriteMemory";
pub const EMULATOR_METHOD_PROOF: &'static str =
    "/CartesiMachineManager.MachineManager/SessionGetProof";

/// Representation of a request for new session
#[derive(Debug, Clone)]
pub struct NewSessionRequest {
    pub machine: cartesi_machine::MachineRequest,
    pub session_id: String,
}

/// Representation of a request for running the machine
#[derive(Debug, Clone)]
pub struct SessionRunRequest {
    pub session_id: String,
    pub times: Vec<u64>,
}

/// Representation of the response of running the machine
#[derive(Debug, Clone)]
pub struct SessionRunResponse {
    pub one_of: SessionRunResponseOneOf,
}

#[derive(Debug, Clone)]
pub enum SessionRunResponseOneOf {
    RunProgress(SessionRunProgress),
    RunResult(SessionRunResult),
}

#[derive(Debug, Clone)]
pub struct SessionRunProgress {
    pub progress: u64,
    pub application_progress: u64,
    pub updated_at: u64,
    pub cycle: u64,
}

#[derive(Debug, Clone)]
pub struct SessionRunResult {
    pub hashes: Vec<H256>,
}

impl From<machine_manager::SessionRunResponse_oneof_run_oneof> for SessionRunResponseOneOf {
    fn from(one_of: machine_manager::SessionRunResponse_oneof_run_oneof) -> Self {
        match one_of {
            machine_manager::SessionRunResponse_oneof_run_oneof::progress(s)
            => {
                SessionRunResponseOneOf::RunProgress(s.into())
            },
            machine_manager::SessionRunResponse_oneof_run_oneof::result(p)
            => {
                SessionRunResponseOneOf::RunResult(p.into())
            },
        }
    }
}

impl From<machine_manager::SessionRunProgress> for SessionRunProgress {
    fn from(run_progress: machine_manager::SessionRunProgress) -> Self {
        SessionRunProgress {
            progress: run_progress.progress,
            application_progress: run_progress.application_progress,
            updated_at: run_progress.updated_at,
            cycle: run_progress.cycle,
        }
    }
}

impl From<machine_manager::SessionRunResult> for SessionRunResult {
    fn from(run_result: machine_manager::SessionRunResult) -> Self {
        SessionRunResult {
            hashes: run_result
                .hashes
                .into_vec()
                .into_iter()
                .map(|hash| H256::from_slice(&hash.content))
                .collect(),
        }
    }
}

impl From<machine_manager::SessionRunResponse> for SessionRunResponse {
    fn from(response: machine_manager::SessionRunResponse) -> Self {
        SessionRunResponse {
            one_of: response
                .run_oneof
                .unwrap()
                .into(),
        }
    }
}

/// Representation of the response of creating a new machine
#[derive(Debug, Clone)]
pub struct NewSessionResponse {
    pub hash: H256,
}

impl From<cartesi_machine::Hash> for NewSessionResponse {
    fn from(response: cartesi_machine::Hash) -> Self {
        NewSessionResponse {
            hash: H256::from_slice(&response.content),
        }
    }
}

/// Access operation is either a `Read` or a `Write`
#[derive(Debug, Clone)]
pub enum AccessOperation {
    Read,
    Write,
}

impl From<cartesi_machine::AccessOperation> for AccessOperation {
    fn from(op: cartesi_machine::AccessOperation) -> Self {
        match op {
            cartesi_machine::AccessOperation::READ => AccessOperation::Read,
            cartesi_machine::AccessOperation::WRITE => AccessOperation::Write,
        }
    }
}

/// A proof that a certain subtree has the contents represented by
/// `target_hash`.
#[derive(Debug, Clone)]
pub struct Proof {
    pub address: u64,
    pub log2_size: u32,
    pub target_hash: H256,
    pub sibling_hashes: Vec<H256>,
    pub root_hash: H256,
}

impl From<cartesi_machine::Proof> for Proof {
    fn from(proof: cartesi_machine::Proof) -> Self {
        Proof {
            address: proof.address,
            log2_size: proof.log2_size,
            target_hash: H256::from_slice(
                &proof
                    .target_hash
                    .into_option()
                    .expect("target hash not found")
                    .content,
            ),
            sibling_hashes: proof
                .sibling_hashes
                .into_vec()
                .into_iter()
                .map(|hash| H256::from_slice(&hash.content))
                .collect(),
            root_hash: H256::from_slice(
                &proof
                    .root_hash
                    .into_option()
                    .expect("root hash not found")
                    .content,
            ),
        }
    }
}

/// An access to be logged during the step procedure
#[derive(Debug, Clone)]
pub struct Access {
    pub operation: AccessOperation,
    pub address: u64,
    pub value_read: [u8; 8],
    pub value_written: [u8; 8],
    pub proof: Proof,
}

fn to_bytes(input: Vec<u8>) -> Option<[u8; 8]> {
    if input.len() != 8 {
        None
    } else {
        Some([
            input[0], input[1], input[2], input[3], input[4], input[5], input[6], input[7],
        ])
    }
}

impl From<cartesi_machine::Access> for Access {
    fn from(access: cartesi_machine::Access) -> Self {
        let proof: Proof = access.proof.into_option().expect("proof not found").into();
        Access {
            operation: access.operation.into(),
            address: proof.address,
            value_read: to_bytes(
                access
                    .read
                    .into_option()
                    .expect("read access not found")
                    .content,
            )
            .expect("read value has the wrong size"),
            value_written: to_bytes(
                access
                    .written
                    .into_option()
                    .expect("write access not found")
                    .content,
            )
            .expect("write value has the wrong size"),
            proof: proof,
        }
    }
}

/// A representation of a request for a logged machine step
#[derive(Debug, Clone)]
pub struct SessionStepRequest {
    pub session_id: String,
    pub time: u64,
}

/// A representation of the response of a logged machine step
#[derive(Debug, Clone)]
pub struct SessionStepResponse {
    pub log: Vec<Access>,
}

impl From<machine_manager::SessionStepResponse> for SessionStepResponse {
    fn from(response: machine_manager::SessionStepResponse) -> Self {
        SessionStepResponse {
            log: response
                .log
                .into_option()
                .expect("log not found")
                .accesses
                .into_vec()
                .into_iter()
                .map(|hash| hash.into())
                .collect(),
        }
    }
}

/// Representation of a request for read the memory
#[derive(Debug, Clone)]
pub struct SessionReadMemoryRequest {
    pub session_id: String,
    pub time: u64,
    pub position: cartesi_machine::ReadMemoryRequest,
}

/// A response from the read memory procedure
#[derive(Debug, Clone)]
pub struct ReadMemoryResponse {
    pub data: Vec<u8>,
}

impl From<cartesi_machine::ReadMemoryResponse> for ReadMemoryResponse {
    fn from(read: cartesi_machine::ReadMemoryResponse) -> Self {
        ReadMemoryResponse { data: read.data }
    }
}

/// Representation of a response for read the memory
#[derive(Debug, Clone)]
pub struct SessionReadMemoryResponse {
    pub read_content: ReadMemoryResponse,
}

impl From<machine_manager::SessionReadMemoryResponse> for SessionReadMemoryResponse {
    fn from(response: machine_manager::SessionReadMemoryResponse) -> Self {
        SessionReadMemoryResponse {
            read_content: response
                .read_content
                .into_option()
                .expect("read_content not found")
                .into(),
        }
    }
}

/// Representation of a request for get proof
#[derive(Debug, Clone)]
pub struct SessionGetProofRequest {
    pub session_id: String,
    pub time: u64,
    pub target: cartesi_machine::GetProofRequest,
}

/// Representation of a response for read the memory
#[derive(Debug, Clone)]
pub struct SessionGetProofResponse {
    pub proof: Proof,
}

impl From<cartesi_machine::Proof> for SessionGetProofResponse {
    fn from(proof: cartesi_machine::Proof) -> Self {
        SessionGetProofResponse {
            proof: proof.into(),
        }
    }
}

impl From<Vec<u8>> for SessionRunResponse {
    fn from(response: Vec<u8>) -> Self {
        let marshaller: Box<dyn Marshaller<machine_manager::SessionRunResponse> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);
        marshaller
            .read(bytes::Bytes::from(response))
            .unwrap()
            .into()
    }
}

impl From<Vec<u8>> for SessionStepResponse {
    fn from(response: Vec<u8>) -> Self {
        let marshaller: Box<dyn Marshaller<machine_manager::SessionStepResponse> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);
        marshaller
            .read(bytes::Bytes::from(response))
            .unwrap()
            .into()
    }
}

impl From<Vec<u8>> for NewSessionResponse {
    fn from(response: Vec<u8>) -> Self {
        let marshaller: Box<dyn Marshaller<cartesi_machine::Hash> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);
        marshaller
            .read(bytes::Bytes::from(response))
            .unwrap()
            .into()
    }
}

impl From<Vec<u8>> for SessionReadMemoryResponse {
    fn from(response: Vec<u8>) -> Self {
        let marshaller: Box<dyn Marshaller<machine_manager::SessionReadMemoryResponse> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);
        marshaller
            .read(bytes::Bytes::from(response))
            .unwrap()
            .into()
    }
}

impl From<Vec<u8>> for SessionGetProofResponse {
    fn from(response: Vec<u8>) -> Self {
        let marshaller: Box<dyn Marshaller<cartesi_machine::Proof> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);
        marshaller
            .read(bytes::Bytes::from(response))
            .unwrap()
            .into()
    }
}

impl From<SessionRunRequest> for Vec<u8> {
    fn from(request: SessionRunRequest) -> Self {
        let marshaller: Box<dyn Marshaller<machine_manager::SessionRunRequest> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);

        let mut req = machine_manager::SessionRunRequest::new();
        req.set_session_id(request.session_id);
        req.set_final_cycles(request.times);

        marshaller.write(&req).unwrap()
    }
}

impl From<SessionStepRequest> for Vec<u8> {
    fn from(request: SessionStepRequest) -> Self {
        let marshaller: Box<dyn Marshaller<machine_manager::SessionStepRequest> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);

        let mut req = machine_manager::SessionStepRequest::new();
        req.set_session_id(request.session_id);
        req.set_initial_cycle(request.time);

        marshaller.write(&req).unwrap()
    }
}

impl From<NewSessionRequest> for Vec<u8> {
    fn from(request: NewSessionRequest) -> Self {
        let marshaller: Box<dyn Marshaller<machine_manager::NewSessionRequest> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);

        let mut req = machine_manager::NewSessionRequest::new();
        req.set_session_id(request.session_id);
        req.set_machine(request.machine);

        marshaller.write(&req).unwrap()
    }
}

impl From<SessionReadMemoryRequest> for Vec<u8> {
    fn from(request: SessionReadMemoryRequest) -> Self {
        let marshaller: Box<dyn Marshaller<machine_manager::SessionReadMemoryRequest> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);

        let mut req = machine_manager::SessionReadMemoryRequest::new();
        req.set_session_id(request.session_id);
        req.set_cycle(request.time);
        req.set_position(request.position);

        marshaller.write(&req).unwrap()
    }
}

impl From<SessionGetProofRequest> for Vec<u8> {
    fn from(request: SessionGetProofRequest) -> Self {
        let marshaller: Box<dyn Marshaller<machine_manager::SessionGetProofRequest> + Sync + Send> =
            Box::new(grpc::protobuf::MarshallerProtobuf);

        let mut req = machine_manager::SessionGetProofRequest::new();
        req.set_session_id(request.session_id);
        req.set_cycle(request.time);
        req.set_target(request.target);

        marshaller.write(&req).unwrap()
    }
}

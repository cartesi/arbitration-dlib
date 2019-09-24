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


#![warn(unused_extern_crates)]
pub mod compute;
pub mod mm;
pub mod partition;
pub mod vg;
pub mod emulator_service;

extern crate configuration;
extern crate error;
extern crate grpc;
extern crate bytes;

#[macro_use]
extern crate serde_derive;
#[macro_use]
extern crate log;
extern crate dispatcher;
extern crate ethabi;
extern crate ethereum_types;
extern crate transaction;
extern crate emulator_interface;

use ethereum_types::{Address, U256};
use grpc::marshall::Marshaller;

pub use compute::{Compute, ComputeCtx, ComputeCtxParsed};
pub use mm::MM;
pub use partition::Partition;
pub use vg::VG;
pub use emulator_interface::{cartesi_base, manager_high};
pub use emulator_service::{
    AccessOperation, NewSessionRequest, NewSessionResult,
    SessionRunRequest, SessionStepRequest,
    SessionRunResult, SessionStepResult,
    EMULATOR_SERVICE_NAME, EMULATOR_METHOD_NEW,
    EMULATOR_METHOD_RUN, EMULATOR_METHOD_STEP};

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

pub fn build_machine_id(_index: U256, _address: &Address) -> String {
    //return format!("{:x}:{}", address, index);
    //return "0000000000000000000000000000000000000000000000008888888888888888"
    //    .to_string();
    return "test_new_session_id".to_string();
}

pub fn build_session_run_key(id: String, start_time: String, final_time: String, query_size: String) -> String {
    return format!("{}_run_{}_{}_{}", id, start_time, final_time, query_size);
}

pub fn build_session_step_key(id: String, divergence_time: String) -> String {
    return format!("{}_step_{}", id, divergence_time);
}

impl From<Vec<u8>>
    for SessionRunResult
{
    fn from(
        response: Vec<u8>,
    ) -> Self {
        let marshaller: Box<dyn Marshaller<manager_high::SessionRunResult> + Sync + Send> = Box::new(grpc::protobuf::MarshallerProtobuf);
        marshaller.read(bytes::Bytes::from(response)).unwrap().into()
    }
}

impl From<Vec<u8>>
    for SessionStepResult
{
    fn from(
        response: Vec<u8>,
    ) -> Self {
        let marshaller: Box<dyn Marshaller<manager_high::SessionStepResult> + Sync + Send> = Box::new(grpc::protobuf::MarshallerProtobuf);
        marshaller.read(bytes::Bytes::from(response)).unwrap().into()
    }
}

impl From<Vec<u8>>
    for NewSessionResult
{
    fn from(
        response: Vec<u8>,
    ) -> Self {
        let marshaller: Box<dyn Marshaller<cartesi_base::Hash> + Sync + Send> = Box::new(grpc::protobuf::MarshallerProtobuf);
        marshaller.read(bytes::Bytes::from(response)).unwrap().into()
    }
}

impl From<SessionRunRequest>
    for Vec<u8>
{
    fn from(
        request: SessionRunRequest,
    ) -> Self {
        let marshaller: Box<dyn Marshaller<manager_high::SessionRunRequest> + Sync + Send> = Box::new(grpc::protobuf::MarshallerProtobuf);
    
        let mut req = manager_high::SessionRunRequest::new();
        req.set_session_id(request.session_id);
        req.set_final_cycles(request.times);

        marshaller.write(&req).unwrap()
    }
}

impl From<SessionStepRequest>
    for Vec<u8>
{
    fn from(
        request: SessionStepRequest,
    ) -> Self {
        let marshaller: Box<dyn Marshaller<manager_high::SessionStepRequest> + Sync + Send> = Box::new(grpc::protobuf::MarshallerProtobuf);
    
        let mut req = manager_high::SessionStepRequest::new();
        req.set_session_id(request.session_id);
        req.set_initial_cycle(request.time);

        marshaller.write(&req).unwrap()
    }
}

impl From<NewSessionRequest>
    for Vec<u8>
{
    fn from(
        request: NewSessionRequest,
    ) -> Self {
        let marshaller: Box<dyn Marshaller<manager_high::NewSessionRequest> + Sync + Send> = Box::new(grpc::protobuf::MarshallerProtobuf);
    
        let mut req = manager_high::NewSessionRequest::new();
        req.set_session_id(request.session_id);
        req.set_machine(request.machine);

        marshaller.write(&req).unwrap()
    }
}
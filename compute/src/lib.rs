#![feature(proc_macro_hygiene, generators, transpose_result)]

pub mod compute;
pub mod mm;
pub mod partition;
pub mod vg;

extern crate configuration;
extern crate emulator;
extern crate emulator_interface;
extern crate env_logger;
extern crate error;

#[macro_use]
extern crate serde_derive;
#[macro_use]
extern crate log;
extern crate dispatcher;
extern crate ethabi;
extern crate ethereum_types;
extern crate hex;
extern crate serde;
extern crate serde_json;
extern crate state;
extern crate time;
extern crate transaction;

use ethereum_types::{Address, U256};

pub use compute::Compute;
pub use mm::MM;
pub use partition::Partition;
pub use vg::VG;

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

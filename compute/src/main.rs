// error-chain recursion
#![recursion_limit = "1024"]

extern crate compute;
extern crate dispatcher;
extern crate env_logger;
extern crate error;
extern crate utils;

use compute::Compute;
use dispatcher::Dispatcher;
use utils::print_error;

fn main() {
    env_logger::init();

    let dispatcher = match Dispatcher::new() {
        Ok(d) => d,
        Err(ref e) => {
            print_error(e);
            return;
        }
    };

    dispatcher.run::<Compute>();
}

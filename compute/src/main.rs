// Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.

// Copyright 2019 Cartesi Pte. Ltd.

// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
// error-chain recursion
#![recursion_limit = "1024"]
#![warn(unused_extern_crates)]

extern crate compute;
extern crate dispatcher;
extern crate env_logger;
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

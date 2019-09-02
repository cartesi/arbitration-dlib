const yaml = require('js-yaml');
const fs   = require('fs');
var path = require('path');

var rel = "../build/contracts";

var ArbitrationTestPath = path.join(__dirname, rel, "/ArbitrationTestInstantiator.json");
var ArbitrationTestInstantiator = artifacts.require("./ArbitrationTestInstantiator.sol");

const final_time = 100000000;
const round_duration = 100000;
const initial_hash = "0xc7e2b1fbc7e499cca84d5bf8eb89a7e8c683e1605a7ebda9c3362fa491d556c8";
const MAIN_ACCOUNT = "0x2ad38f50f38abc5cbcf175e1962293eecc7936de";
const SECOND_ACCOUNT = "0x8b5432ca3423f3c310eba126c1d15809c61aa0a9";

module.exports = function(deployer, network, accounts) {
  deployer.then(async () => {
    let computeAddress;
    let stepAddress;
    if (process.env.CARTESI_INTEGRATION_COMPUTE_ADDR) {
      computeAddress = process.env.CARTESI_INTEGRATION_COMPUTE_ADDR
    } else {
        //return error
    }
    if (process.env.CARTESI_INTEGRATION_STEP_ADDR) {
        stepAddress = process.env.CARTESI_INTEGRATION_STEP_ADDR
    } else {
        //return error
    }

    await deployer.deploy(ArbitrationTestInstantiator,
                        MAIN_ACCOUNT,
                        SECOND_ACCOUNT,
                        round_duration,
                        stepAddress,
                        computeAddress,
                        initial_hash,
                        final_time);
    let ArbitrationTestContract = await ArbitrationTestInstantiator.deployed();
    console.log("ArbitrationTestInstantiator: " + ArbitrationTestContract.address);
    if (typeof process.env.CARTESI_CONFIG_FILE_PATH !== "undefined"){
      var arbitration_test_concern = {
        contract_address: ArbitrationTestContract.address,
        user_address: accounts[0],
        abi: ArbitrationTestPath,
      }
      var full_concerns = yaml.safeLoad(fs.readFileSync(process.env.CARTESI_CONFIG_FILE_PATH, 'utf8'));
      full_concerns['concerns'].push(arbitration_test_concern);
      fs.writeFileSync(process.env.CARTESI_CONFIG_FILE_PATH, yaml.dump(full_concerns));
    } else {
        //return error
    }
  });
};

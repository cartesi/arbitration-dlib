const BigNumber = require('bignumber.js');
const expect = require('chai').expect;

const mm = require('./mm.js');
const getEvent = require('../utils/tools.js').getEvent;
const unwrap = require('../utils/tools.js').unwrap;
const getError = require('../utils/tools.js').getError;
const twoComplement32 = require('../utils/tools.js').twoComplement32;

var TH = artifacts.require("./TestHash.sol");

contract('MMInstantiator', function(accounts) {
  it('Checking functionalities', async function() {

    // launch contract from account[2], who will be the owner
    let th = await TH.new();


    response = await th.testing(
      '0x012345678abcdeff', 1234678987,
      { from: accounts[2], gas: 2000000 });
    //console.log(response.logs);
  })
})

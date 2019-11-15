const HDWalletProvider = require("@truffle/hdwallet-provider");
const project = process.env.PROJECT_ID;
const mnemonic = process.env.MNEMONIC;

const network = (name, network_id) => ({
  provider: () => new HDWalletProvider(mnemonic, `https://${name}.infura.io/v3/${project}`),
  network_id
});

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 6283185
    },
    ganache: {
      host: "ganache",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 6283185
    },
    geth: {
      host: "geth",
      port: 8545,
      network_id: "15", // Match any network id
      gas: 6283185
    },
    ropsten: network('ropsten', 3),
    kovan: network('kovan', 42),
    rinkeby: network('rinkeby', 4),
    solc: {
     optimizer: { // Turning on compiler optimization that removes some local variables during compilation
       enabled: true,
       runs: 200
      }
    }
  }
};

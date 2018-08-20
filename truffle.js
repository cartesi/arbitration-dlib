module.exports = {
  networks: {
     development: {
       host: "localhost",
       port: 8545,
       network_id: "*", // Match any network id
       gas: 3500000
     }
   },
   mocha: {
    useColors: true
   }
};

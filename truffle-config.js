const HDWalletProvider = require('@truffle/hdwallet-provider');
const fs = require('fs');
const memphrase = fs.readFileSync(".secret").toString().trim();

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard BSC port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    testnet: {
      disableConfirmationListener:true,
      provider: () => new HDWalletProvider({mnemonic:{phrase:memphrase}, providerOrUrl:`https://data-seed-prebsc-1-s2.binance.org:8545`, pollingInterval: 60000}, ),
      network_id: 97,
      confirmations: 3,
      disableConfirmationListener:true,
      //timeoutBlocks: 200,
      //pollingInterval: 10000,
      gas:10721975,
      skipDryRun: false,
      networkCheckTimeout: 100000000,
      timeoutBlocks: 50000,
      enableTimeouts:false
    },

    bsc: {
      provider: () => new HDWalletProvider({mnemonic:{phrase:memphrase}, providerOrUrl:`https://bsc-dataseed.binance.org`, pollingInterval: 60000}, ),
      network_id: 56,
      confirmations: 3,
      timeoutBlocks: 200,
      skipDryRun: true
    },

    matic: {
      provider: () => new HDWalletProvider({mnemonic:{phrase:memphrase}, providerOrUrl:`https://rpc-mainnet.maticvigil.com/v1/a32fc877ebba7a3dd27ff7c0fee575abeb79f92d`, pollingInterval: 60000}, ),
      network_id: 137,
      confirmations: 3,
      disableConfirmationListener:true,
      //timeoutBlocks: 200,
      //pollingInterval: 10000,
      gas:5000000,
      confirmations: 3,
      gas:10000000,
      gasPrice:'90000000000',
      skipDryRun: false,
      networkCheckTimeout: 100000000,
      timeoutBlocks: 50000,
      enableTimeouts:false,
      disableConfirmationListener:true,
    },

    cronos: {
      provider: () => new HDWalletProvider({mnemonic:{phrase:memphrase}, providerOrUrl:`https://evm-cronos.crypto.org/`, pollingInterval: 60000}, ),
      network_id: 25,
      confirmations: 3,
      timeoutBlocks: 200,
      skipDryRun: true
    },

    testpulse: {
      provider: () => new HDWalletProvider({mnemonic:{phrase:memphrase}, providerOrUrl:`https://rpc.testnet.pulsechain.com`, pollingInterval: 60000}, ),
      network_id: 940,
      confirmations: 3,
      timeoutBlocks: 200,
      skipDryRun: true
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
     //timeout: 10000000000000,
    enableTimeouts: false,
    before_timeout: 12000000000000 
  },

  plugins: ["truffle-contract-size"],

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.7.4"
    }
  },
}
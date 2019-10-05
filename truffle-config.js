/**
 * Truffle config for Vulcan Swap
 */

/**
 * Uncomment the following lines if you want to deploy to a live network.
 * You will also need to create a .env file with an INFURA_KEY constant.
 * You will also need to create a `.secret` file with a private key.
 */
// require('dotenv').config()
// const HDWalletProvider = require('truffle-hdwallet-provider');
// const infuraKey = process.env.INFURA_KEY;
// const fs = require('fs');
// const mnemonic = fs.readFileSync('.secret').toString().trim();

const path = require('path');

module.exports = {

  /**
   * Optional dev plugins (install before using):
   */

  // plugins: [
  //   "truffle-security",
  //   "truffle-plugin-verify"
  // ],

  // Optional plugin config: Truffle Verify
  // api_keys: {
  //   etherscan: process.env.ETHERSCAN_API_KEY
  // },

  /**
   * Contract compile and build directory options:
   */

  // Need to do this to get contracts inside the create-react-app folder
  contracts_build_directory: path.join(__dirname, 'client/src/contracts'),

  // Only compile necessary contracts
  contracts_directory: path.join(__dirname, 'contracts/deploy'),

  /**
   * Optional dev plugins (install before using):
   */

  networks: {
    // development: {
    //   host: "127.0.0.1",
    //   port: 7545,
    //   network_id: "*",
    // },

    // rinkeby: {
    //   provider: () => new HDWalletProvider(mnemonic, `https://rinkeby.infura.io/v3/${infuraKey}`),
    //   network_id: 4,         // Rinkeby's id
    //   gas: 6500000,          // Rinkeby has a lower block limit than mainnet
    //   gasPrice: 2000000000,  // 2 gwei (in wei) (default: 100 gwei)
    //   skipDryRun: true       // Skip dry run before migrations? (default: false for public nets )
    // }
  },

  /**
   * Compiler config.
   */

  compilers: {
    solc: {
      version: "0.5.8", // This is the solidity version specified for all contracts.
      settings: {
        optimizer: {  // Needs optimizer because Compound contracts are massive.
          enabled: true,
          runs: 200
        },
      }
    }
  }
}

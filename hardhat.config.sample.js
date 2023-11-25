require("@nomicfoundation/hardhat-toolbox");

const PROVIDER_API_KEY = "";
const PROVIDER_URL = `https://provider.url/${PROVIDER_API_KEY}`;
const PRIVATE_KEY = "";

const BLOCK_NUMBER_SYNC = 0;
const BLOCK_GAS_LIMIT = 500000000;


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  networks: {
    hardhat: {
      blockGasLimit: BLOCK_GAS_LIMIT,
      forking: {
        url: PROVIDER_URL,
        blockNumber: BLOCK_NUMBER_SYNC
      }
    },
    ethereum: {
      url: PROVIDER_URL,
      accounts: [PRIVATE_KEY]
    }
  }
};

require("@nomicfoundation/hardhat-toolbox");

const QUICKNODE_API_KEY = ""; // QUICKNODE_API_KEY
const PRIVATE_KEY = ""; // PRIVATE_KEY

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
//  solidity: "0.8.20",
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
      blockGasLimit: 500000000,
      forking: {
        url: `https://quick-capable-dinghy.quiknode.pro/${QUICKNODE_API_KEY}`,
        blockNumber: 18576359
      }
    },
    ethereum: {
      url: `https://quick-capable-dinghy.quiknode.pro/${QUICKNODE_API_KEY}`,
      accounts: [PRIVATE_KEY]
    }
  }
};

require("@nomicfoundation/hardhat-toolbox");

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
        url: "https://quick-capable-dinghy.quiknode.pro/cb4404b6a100ea95db99a0bcf3eafd3184772bcf/",
        blockNumber: 18576359
      }
    }
  }
};

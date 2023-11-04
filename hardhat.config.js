require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      forking: {
        url: "https://quick-capable-dinghy.quiknode.pro/cb4404b6a100ea95db99a0bcf3eafd3184772bcf/",
      }
    }
  }
};

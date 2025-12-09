require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  paths : {
    artifacts: "./artifacts",
    sources: "./contracts/src/",
    cache: "./cache",
  },
  networks: {
    hardhat: {
      accounts: {
        count: 10,
        initialBalance: "10000000000000000000000", // 10,000 ether;
        mnemonic: "test test test test test test test test test test test junk"
      }
    }

  }
};

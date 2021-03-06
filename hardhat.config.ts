import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "dotenv/config";
import "hardhat-typechain";
import { HardhatUserConfig } from "hardhat/types";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{
      version: "0.5.16",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    }, {
      version: "0.8.5",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    }],
  },
  // networks: {
  //   kovan: {
  //     url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
  //     accounts: [process.env.ADMIN || ''],
  //     chainId: 42,
  //   },
  //   rinkeby: {
  //     url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
  //     accounts: [process.env.ADMIN || ''],
  //     chainId: 4,
  //   },
  // },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
};

export default config;

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from 'dotenv';

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  paths: {
    sources: "./src/contracts",
    tests: "./src/test",
    cache: "./src/cache",
    artifacts: "./src/artifacts"
  },
  mocha: {
    timeout: 40000
  },
  networks: {
    hardhat: {},

    // MAINET CONFIG
    ethereum: {
      url: process.env.RPC_ETHEREUM_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    optimism: {
      url: process.env.RPC_OPTIMISM_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    polygon: {
      url: process.env.RPC_POLYGON_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    solana: {
      url: process.env.RPC_SOLANA_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    base: {
      url: process.env.RPC_BASE_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    sei: {
      url: process.env.RPC_SEI_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    bnb: {
      url: process.env.RPC_BNB_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    lisk: {
      url: 'https://rpc.api.lisk.com',
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },

    // MAINET CONFIG
    ethereum_sepolia: {
      url: process.env.RPC_ETHEREUM_SEPOLIA_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    optimism_sepolia: {
      url: process.env.RPC_OPTIMISM_SEPOLIA_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    polygon_sepolia: {
      url: process.env.RPC_POLYGON_AMOY_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    solana_devnet: {
      url: process.env.RPC_SOLANA_DEVNET_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    base_sepolia: {
      url: process.env.RPC_BASE_SEPOLIA_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    sei_testnet: {
      url: process.env.RPC_SEI_TESTNET_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
    bnb_testnet: {
      url: process.env.RPC_BNB_TESTNET_URL ?? "",
      accounts: [process.env.PRIVATE_KEY ?? ""]
    },
  }
};

export default config;

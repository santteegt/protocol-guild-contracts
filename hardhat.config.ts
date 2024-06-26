// NOTICE: hardhat-foundry must be disabled when running pnpm coverage
// import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import { config as dotenvConfig } from "dotenv";
import "hardhat-contract-sizer";
import "hardhat-deploy";
import type { HardhatUserConfig } from "hardhat/config";
import type { NetworkUserConfig } from "hardhat/types";
import { resolve } from "path";

import "./tasks/accounts";
import "./tasks/members";
import "./tasks/registry";
import "./tasks/taskDeploy";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// Ensure that we have all the environment variables we need.
const mnemonic: string = process.env.MNEMONIC || "";
if (!mnemonic) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

const infuraApiKey: string | undefined = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error("Please set your INFURA_API_KEY in a .env file");
}

const chainIds = {
  hardhat: 31337,
  sepolia: 11155111,
  mainnet: 1,
  gnosis: 100,
  "arbitrum-mainnet": 42161,
  "arbitrum-sepolia": 421614,
  "optimism-mainnet": 10,
  "optimism-sepolia": 11155420,
  "polygon-mainnet": 137,
};

const explorerApiKey = (networkName: keyof typeof chainIds) => {
  const fromEnv = () => {
    switch (networkName) {
      case "mainnet":
      case "sepolia":
        return process.env.ETHERSCAN_APIKEY;
      case "gnosis":
        return process.env.GNOSISSCAN_APIKEY;
      case "polygon-mainnet":
        return process.env.POLYGONSCAN_APIKEY;
      case "optimism-mainnet":
      case "optimism-sepolia":
        return process.env.OPTIMISTICSCAN_APIKEY;
      case "arbitrum-mainnet":
      case "arbitrum-sepolia":
        return process.env.ARBISCAN_APIKEY;
      default:
        break;
    }
  };
  return fromEnv() || "";
};

const getNodeURI = (networkName: keyof typeof chainIds) => {
  switch (networkName) {
    case "arbitrum-mainnet":
      return "https://rpc.ankr.com/arbitrum";
    case "arbitrum-sepolia":
      return "https://sepolia-rollup.arbitrum.io/rpc";
    case "optimism-mainnet":
      return "https://rpc.ankr.com/optimism";
    case "optimism-sepolia":
      return "https://sepolia.optimism.io";
    case "polygon-mainnet":
      return "https://rpc.ankr.com/polygon";
    case "gnosis":
      return "https://rpc.gnosischain.com";
    default:
      return "https://" + networkName + ".infura.io/v3/" + infuraApiKey;
  }
};

function getChainConfig(chain: keyof typeof chainIds): NetworkUserConfig {
  const jsonRpcUrl: string = getNodeURI(chain);
  return {
    accounts: process.env.ACCOUNT_PK
      ? [process.env.ACCOUNT_PK]
      : {
          count: 10,
          mnemonic,
          path: "m/44'/60'/0'/0",
        },
    chainId: chainIds[chain],
    url: jsonRpcUrl,
  };
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: 0,
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic,
      },
      chainId: chainIds.hardhat,
      forking: process.env.HARDHAT_FORK_NETWORK
        ? {
            url: getNodeURI(process.env.HARDHAT_FORK_NETWORK as keyof typeof chainIds),
            blockNumber: process.env.HARDHAT_FORK_BLOCKNUMBER
              ? parseInt(process.env.HARDHAT_FORK_BLOCKNUMBER)
              : undefined,
          }
        : undefined,
      companionNetworks: {
        l2: "hardhat",
      },
      initialDate: "2023-05-01T00:00:00.000-05:00",
    },
    // ganache: {
    //   accounts: {
    //     mnemonic,
    //   },
    //   chainId: chainIds.ganache,
    //   url: "http://localhost:8545",
    // },
    // avalanche: getChainConfig("avalanche"),
    // bsc: getChainConfig("bsc"),
    sepolia: {
      ...getChainConfig("sepolia"),
      companionNetworks: {
        "l2-optimism": "optimismSepolia",
        "l2-arbitrum": "arbitrumSepolia",
      },
      gas: 5000000,
      gasPrice: 8000000000,
      gasMultiplier: 2,
    },
    mainnet: getChainConfig("mainnet"),
    gnosis: getChainConfig("gnosis"),
    arbitrum: getChainConfig("arbitrum-mainnet"),
    arbitrumSepolia: {
      ...getChainConfig("arbitrum-sepolia"),
      companionNetworks: {
        l1: "sepolia",
      },
      initialBaseFeePerGas: 1635190000,
      gasPrice: 1635190000,
      gasMultiplier: 1.2,
    },
    optimism: getChainConfig("optimism-mainnet"),
    optimismSepolia: {
      ...getChainConfig("optimism-sepolia"),
      companionNetworks: {
        l1: "sepolia",
      },
      gasPrice: 2000000000,
    },
    polygon: getChainConfig("polygon-mainnet"),
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: false,
    only: [
      "GuildRegistry.sol",
      "GuildRegistryV2.sol",
      "NetworkRegistry.sol",
      "NetworkRegistryV2.sol",
      "PGContribCalculator",
    ],
  },
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.23",
        settings: {
          metadata: {
            // Not including the metadata hash
            // https://github.com/paulrberg/hardhat-template/issues/31
            bytecodeHash: "none",
          },
          // Disable the optimizer when debugging
          // https://hardhat.org/hardhat-network/#solidity-optimizer-support
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 120000,
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
  etherscan: {
    apiKey: {
      mainnet: explorerApiKey("mainnet"),
      sepolia: explorerApiKey("sepolia"),
      optimisticEthereum: explorerApiKey("optimism-mainnet"),
      optimisticSepolia: explorerApiKey("optimism-sepolia"),
      arbitrumOne: explorerApiKey("arbitrum-mainnet"),
      arbitrumSepolia: explorerApiKey("arbitrum-sepolia"),
      polygon: explorerApiKey("polygon-mainnet"),
    },
  },
  external: {
    contracts: [
      {
        artifacts: "node_modules/@daohaus/baal-contracts/export/artifacts",
        deploy: "node_modules/@daohaus/baal-contracts/export/deploy",
      },
    ],
  },
};

export default config;

const { ethers } = require("ethers");

// Load deployment config
let deployment;
try {
  deployment = require("../config/deployment.json");
} catch (error) {
  console.warn("⚠️  Deployment config not found. Run deployment first.");
  deployment = { contracts: {} };
}

// Web3 Setup
const provider = new ethers.JsonRpcProvider(
  process.env.RPC_URL || "https://rpc-amoy.polygon.technology/"
);

const wallet = new ethers.Wallet(process.env.PRIVATE_KEY || "", provider);

// Contract ABIs
const tokenSwapABI = [
  "function swapAtoB(uint256 amount) external",
  "function swapAtoBWithRef(uint256 amount, address referrer) external",
  "function depositLiquidity(uint256 amount) external",
  "function getSwapRate() external view returns (uint256, uint256)",
  "function getTokenABalance() external view returns (uint256)",
  "function getTokenBBalance() external view returns (uint256)",
  "event SwapExecuted(address indexed user, uint256 amountA, uint256 amountB)",
  "event ReferralReward(address indexed referrer, uint256 rewardAmount)",
];

const tokenABI = [
  "function balanceOf(address account) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)",
];

// Get contract instances
const getContracts = () => {
  if (!deployment.contracts?.TokenSwap?.address) {
    throw new Error("Contracts not deployed");
  }

  return {
    tokenSwap: new ethers.Contract(
      deployment.contracts.TokenSwap.address,
      tokenSwapABI,
      wallet
    ),
    tokenA: new ethers.Contract(
      deployment.contracts.TokenA.address,
      tokenABI,
      wallet
    ),
    tokenB: new ethers.Contract(
      deployment.contracts.TokenB.address,
      tokenABI,
      wallet
    ),
  };
};

module.exports = {
  ethers,
  provider,
  wallet,
  deployment,
  tokenSwapABI,
  getContracts,
};

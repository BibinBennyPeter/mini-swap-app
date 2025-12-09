const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Deploying contracts to", hre.network.name);

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy TokenA
  console.log("\n1. Deploying TokenA (AUSD)...");
  const TokenA = await hre.ethers.getContractFactory("TokenA");
  const tokenA = await TokenA.deploy();
  await tokenA.waitForDeployment();
  const tokenAAddress = await tokenA.getAddress();
  console.log("TokenA deployed to:", tokenAAddress);

  // Deploy TokenB
  console.log("\n2. Deploying TokenB (BBTC)...");
  const TokenB = await hre.ethers.getContractFactory("TokenB");
  const tokenB = await TokenB.deploy();
  await tokenB.waitForDeployment();
  const tokenBAddress = await tokenB.getAddress();
  console.log("TokenB deployed to:", tokenBAddress);

  // Deploy TokenSwap
  console.log("\n3. Deploying TokenSwap contract...");
  const TokenSwap = await hre.ethers.getContractFactory("TokenSwap");
  const tokenSwap = await TokenSwap.deploy(tokenAAddress, tokenBAddress);
  await tokenSwap.waitForDeployment();
  const tokenSwapAddress = await tokenSwap.getAddress();
  console.log("TokenSwap deployed to:", tokenSwapAddress);

  // Add initial liquidity
  console.log("\n4. Adding initial liquidity...");
  const liquidityAmount = hre.ethers.parseEther("1000"); // 1000 BBTC
  const approveTx = await tokenB.approve(tokenSwapAddress, liquidityAmount);
  await approveTx.wait();
  console.log("Approved TokenB for TokenSwap");

  const depositTx = await tokenSwap.depositLiquidity(liquidityAmount);
  await depositTx.wait();
  console.log("Deposited 1000 BBTC as liquidity");

  // Transfer some TokenA to contract for referral rewards
  console.log("\n5. Transferring TokenA for referral rewards...");
  const rewardReserve = hre.ethers.parseEther("10000"); // 10000 AUSD
  const transferTx = await tokenA.transfer(tokenSwapAddress, rewardReserve);
  await transferTx.wait();
  console.log("Transferred 10000 AUSD to contract for rewards");

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    chainId: hre.network.config.chainId,
    deployer: deployer.address,
    contracts: {
      TokenA: {
        address: tokenAAddress,
        name: "AUSD Token",
        symbol: "AUSD",
      },
      TokenB: {
        address: tokenBAddress,
        name: "BBTC Token",
        symbol: "BBTC",
      },
      TokenSwap: {
        address: tokenSwapAddress,
      },
    },
    timestamp: new Date().toISOString(),
  };

  // Save to multiple locations
  const deploymentsDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentPath = path.join(
    deploymentsDir,
    `${hre.network.name}.json`
  );
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log("\nDeployment info saved to:", deploymentPath);

  // Save to backend
  const backendDir = path.join(__dirname, "../backend/config");
  if (!fs.existsSync(backendDir)) {
    fs.mkdirSync(backendDir, { recursive: true });
  }
  fs.writeFileSync(
    path.join(backendDir, "deployment.json"),
    JSON.stringify(deploymentInfo, null, 2)
  );

  // Save to frontend
  const frontendDir = path.join(__dirname, "../frontend/src/config");
  if (!fs.existsSync(frontendDir)) {
    fs.mkdirSync(frontendDir, { recursive: true });
  }
  fs.writeFileSync(
    path.join(frontendDir, "deployment.json"),
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("\nDeployment Summary:");
  console.log("═══════════════════════════════════════");
  console.log("Network:", hre.network.name);
  console.log("TokenA (AUSD):", tokenAAddress);
  console.log("TokenB (BBTC):", tokenBAddress);
  console.log("TokenSwap:", tokenSwapAddress);
  console.log("═══════════════════════════════════════\n");

  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("Waiting 30 seconds before verification...");
    await new Promise((resolve) => setTimeout(resolve, 30000));

    console.log("\nVerifying contracts on Polygonscan...");
    try {
      await hre.run("verify:verify", {
        address: tokenAAddress,
        constructorArguments: [],
      });
      console.log("TokenA verified");
    } catch (error) {
      console.log("TokenA verification failed:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: tokenBAddress,
        constructorArguments: [],
      });
      console.log("TokenB verified");
    } catch (error) {
      console.log("TokenB verification failed:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: tokenSwapAddress,
        constructorArguments: [tokenAAddress, tokenBAddress],
      });
      console.log("TokenSwap verified");
    } catch (error) {
      console.log("TokenSwap verification failed:", error.message);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

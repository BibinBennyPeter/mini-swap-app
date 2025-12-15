const express = require("express");
const router = express.Router();
const User = require("../models/User");
const { ethers, getContracts } = require("../services/blockchain");
const { updateUserStats } = require("../services/UserStats");

// POST /swap
router.post("/swap", async (req, res) => {
  try {
    const { userAddress, referalAddress, amount } = req.body;
    if (!userAddress || !amount) {
      return res.status(400).json({ error: "userAddress and amount are required" });
    }
    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({ error: "Invalid userAddress" });
    }
    if (referalAddress && !ethers.isAddress(referalAddress)) {
      return res.status(400).json({ error: "Invalid referalAddress" });
    }
    const amountWei = ethers.parseEther(amount.toString());
    const { tokenSwap, tokenA } = getContracts();
    const approveTx = await tokenA.approve(
      await tokenSwap.getAddress(),
      amountWei
    );
    await approveTx.wait();
    let swapTx;
    if (referalAddress) {
      swapTx = await tokenSwap.swapAtoBWithRef(
        amountWei,
        referalAddress.toLowerCase()
      );
    } else {
      swapTx = await tokenSwap.swapAtoB(amountWei);
    }
    await swapTx.wait();
    await updateUserStats(userAddress.toLowerCase(), amountWei, referalAddress ? referalAddress.toLowerCase() : null);
    res.json({
      success: true,
      txHash: swapTx.hash,
      message: `Swapped ${amount} TokenA for TokenB`,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /user/:address
router.get("/user/:address", async (req, res) => {
  try {
    const { address } = req.params;

    if (!ethers.isAddress(address)) {
      return res.status(400).json({ error: "Invalid address" });
    }

    let user = await User.findOne({ address: address.toLowerCase() });

    if (!user) {
      return res.json({
        totalSwaps: 0,
        totalReferred: 0,
        referralRewardsEarned: "0",
      });
    }

    res.json({
      totalSwaps: user.totalSwaps,
      totalReferred: user.totalReferred,
      referralRewardsEarned: ethers.formatEther(user.referralRewardsEarned),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /admin/liquidity
router.post("/admin/liquidity", async (req, res) => {
  try {
    const { amount } = req.body;

    if (!amount) {
      return res.status(400).json({ error: "Amount required" });
    }

    const amountWei = ethers.parseEther(amount.toString());
    const { tokenSwap, tokenB } = getContracts();

    const approveTx = await tokenB.approve(
      await tokenSwap.getAddress(),
      amountWei
    );
    await approveTx.wait();

    const depositTx = await tokenSwap.depositLiquidity(amountWei);
    await depositTx.wait();

    res.json({
      success: true,
      txHash: depositTx.hash,
      message: `Added ${amount} TokenB liquidity`,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;

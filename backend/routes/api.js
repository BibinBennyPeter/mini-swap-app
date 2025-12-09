const express = require("express");
const router = express.Router();
const User = require("../models/User");
const { ethers, getContracts } = require("../services/blockchain");
const { updateUserStats } = require("../services/UserStats");

// POST /swap
router.post("/swap", async (req, res) => {
  try {
    const { txHash } = req.body;

    if (!txHash) {
      return res.status(400).json({ error: "Transaction hash required" });
    }

    await updateUserStats(txHash);

    res.json({
      success: true,
      message: "Stats updated successfully",
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

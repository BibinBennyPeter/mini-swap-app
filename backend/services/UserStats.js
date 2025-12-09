const User = require("../models/User");
const { provider, getContracts, ethers, tokenSwapABI } = require("./blockchain");

// Update user stats from transaction
async function updateUserStats(txHash) {
  try {
    const receipt = await provider.getTransactionReceipt(txHash);
    if (!receipt) return;

    const iface = new ethers.Interface(tokenSwapABI);

    for (const log of receipt.logs) {
      try {
        const parsed = iface.parseLog(log);

        if (parsed.name === "SwapExecuted") {
          const [user, amountA, amountB] = parsed.args;
          await updateSwapStats(user.toLowerCase());
        } else if (parsed.name === "ReferralReward") {
          const [referrer, rewardAmount] = parsed.args;
          await updateReferralStats(referrer.toLowerCase(), rewardAmount.toString());
        }
      } catch (e) {
        continue;
      }
    }
  } catch (error) {
    console.error("Error updating user stats:", error);
  }
}

async function updateSwapStats(userAddress) {
  let user = await User.findOne({ address: userAddress });
  if (!user) {
    user = new User({ address: userAddress });
  }

  user.totalSwaps += 1;
  await user.save();
}

async function updateReferralStats(referrerAddress, rewardAmount) {
  let user = await User.findOne({ address: referrerAddress });
  if (!user) {
    user = new User({ address: referrerAddress });
  }

  user.totalReferred += 1;
  user.referralRewardsEarned = (
    BigInt(user.referralRewardsEarned) + BigInt(rewardAmount)
  ).toString();

  await user.save();
}

module.exports = {
  updateUserStats,
};

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenSwap {
    // Events
    event SwapExecuted(address indexed user, uint256 amountA, uint256 amountB);
    event ReferralReward(address indexed referrer, uint256 rewardAmount);
    event LiquidityDeposited(address indexed admin, uint256 amount);
    event TokensWithdrawn(address indexed admin, address token, uint256 amount);

    // Core swap functions
    function swapAtoB(uint256 amount) external;
    function swapAtoBWithRef(uint256 amount, address referrer) external;

    // Admin functions
    function depositLiquidity(uint256 amount) external;
    function withdrawTokens(address token, uint256 amount) external;
    function pause() external;
    function unpause() external;

    // View functions
    function getSwapRate() external pure returns (uint256 numerator, uint256 denominator);
    function getReferralRate() external pure returns (uint256);
}

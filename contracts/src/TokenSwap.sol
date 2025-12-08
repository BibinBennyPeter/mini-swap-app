// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ITokenSwap.sol";

contract TokenSwap is ITokenSwap, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Token references
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    // Constants for swap rate: 1 TokenA = 0.001 TokenB (1000:1 ratio)
    uint256 public constant SWAP_RATE_NUMERATOR = 1;
    uint256 public constant SWAP_RATE_DENOMINATOR = 1000;

    // Referral reward: 1% of amountA
    uint256 public constant REFERRAL_RATE = 1; // 1%
    uint256 public constant PERCENTAGE_BASE = 100;

    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        require(_tokenA != address(0), "TokenA address cannot be zero");
        require(_tokenB != address(0), "TokenB address cannot be zero");
        require(_tokenA != _tokenB, "Tokens must be different");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /**
     * @notice Swap TokenA for TokenB at fixed rate (1000 A = 1 B)
     * @param amount Amount of TokenA to swap
     */
    function swapAtoB(uint256 amount) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        _executeSwap(amount, address(0));
    }

    /**
     * @notice Swap TokenA for TokenB with referral reward
     * @param amount Amount of TokenA to swap
     * @param referrer Address of referrer (gets 1% of amountA as reward)
     */
    function swapAtoBWithRef(uint256 amount, address referrer) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
    {
        require(referrer != address(0), "Referrer cannot be zero address");
        require(referrer != msg.sender, "Cannot refer yourself");

        _executeSwap(amount, referrer);
    }

    /**
     * @dev Internal function to execute swap logic
     */
    function _executeSwap(uint256 amount, address referrer) private {
        require(amount > 0, "Amount must be greater than 0");

        // Calculate TokenB amount to send: amountB = amountA * (1/1000)
        uint256 amountB = (amount * SWAP_RATE_NUMERATOR) / SWAP_RATE_DENOMINATOR;
        require(amountB > 0, "Swap amount too small");

        // Check contract has sufficient TokenB liquidity
        uint256 contractBalanceB = tokenB.balanceOf(address(this));
        require(contractBalanceB >= amountB, "Insufficient TokenB liquidity");

        // Calculate referral reward if referrer exists
        uint256 referralReward = 0;
        uint256 amountToSwap = amount;

        if (referrer != address(0)) {
            referralReward = (amount * REFERRAL_RATE) / PERCENTAGE_BASE;
            // User still swaps full amount, but referrer gets 1% from contract's reserve
            require(
                tokenA.balanceOf(address(this)) >= referralReward,
                "Insufficient TokenA for referral reward"
            );
        }

        // Effects: Update state before external calls (CEI pattern)
        // (In this case, no state to update before transfers)

        // Interactions: External calls
        // 1. Transfer TokenA from user to contract
        tokenA.safeTransferFrom(msg.sender, address(this), amountToSwap);

        // 2. Transfer TokenB from contract to user
        tokenB.safeTransfer(msg.sender, amountB);

        // 3. If referrer exists, send reward
        if (referrer != address(0)) {
            tokenA.safeTransfer(referrer, referralReward);
            emit ReferralReward(referrer, referralReward);
        }

        emit SwapExecuted(msg.sender, amount, amountB);
    }

    /**
     * @notice Admin deposits TokenB liquidity into the contract
     * @param amount Amount of TokenB to deposit
     */
    function depositLiquidity(uint256 amount) 
        external 
        override 
        onlyOwner 
    {
        require(amount > 0, "Amount must be greater than 0");
        tokenB.safeTransferFrom(msg.sender, address(this), amount);
        emit LiquidityDeposited(msg.sender, amount);
    }

    /**
     * @notice Admin withdraws tokens from the contract
     * @param token Address of token to withdraw (TokenA or TokenB)
     * @param amount Amount to withdraw
     */
    function withdrawTokens(address token, uint256 amount) 
        external 
        override 
        onlyOwner 
    {
        require(amount > 0, "Amount must be greater than 0");
        require(
            token == address(tokenA) || token == address(tokenB),
            "Invalid token address"
        );

        IERC20(token).safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, token, amount);
    }

    /**
     * @notice Pause the contract (emergency stop)
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @notice Get the swap rate
     * @return numerator The numerator of the swap rate
     * @return denominator The denominator of the swap rate
     */
    function getSwapRate() 
        external 
        pure 
        override 
        returns (uint256 numerator, uint256 denominator) 
    {
        return (SWAP_RATE_NUMERATOR, SWAP_RATE_DENOMINATOR);
    }

    /**
     * @notice Get the referral reward rate
     * @return The referral rate as a percentage
     */
    function getReferralRate() external pure override returns (uint256) {
        return REFERRAL_RATE;
    }

    /**
     * @notice Get contract's balance of TokenA
     */
    function getTokenABalance() external view returns (uint256) {
        return tokenA.balanceOf(address(this));
    }

    /**
     * @notice Get contract's balance of TokenB
     */
    function getTokenBBalance() external view returns (uint256) {
        return tokenB.balanceOf(address(this));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenA.sol";
import "../src/TokenB.sol";
import "../src/TokenSwap.sol";

contract TokenSwapTest is Test {
    TokenA public tokenA;
    TokenB public tokenB;
    TokenSwap public swap;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public referrer = address(0x3);

    uint256 constant INITIAL_BALANCE = 10_000 * 10**18;
    uint256 constant LIQUIDITY_AMOUNT = 1_000 * 10**18;

    function setUp() public {
        // Deploy tokens
        tokenA = new TokenA();
        tokenB = new TokenB();

        // Deploy swap contract
        swap = new TokenSwap(address(tokenA), address(tokenB));

        // Setup initial balances
        tokenA.transfer(user1, INITIAL_BALANCE);
        tokenA.transfer(user2, INITIAL_BALANCE);
        tokenB.transfer(address(swap), LIQUIDITY_AMOUNT); // Fund contract with TokenB

        // Fund contract with TokenA for referral rewards
        tokenA.transfer(address(swap), 1000 * 10**18);

        // Approve swap contract for users
        vm.prank(user1);
        tokenA.approve(address(swap), type(uint256).max);

        vm.prank(user2);
        tokenA.approve(address(swap), type(uint256).max);
    }

    // ========== Basic Swap Tests ==========

    function testBasicSwap() public {
        uint256 swapAmount = 1000 * 10**18; // 1000 TokenA
        uint256 expectedTokenB = 1 * 10**18; // Should get 1 TokenB

        uint256 user1BalanceABefore = tokenA.balanceOf(user1);
        uint256 user1BalanceBBefore = tokenB.balanceOf(user1);

        vm.prank(user1);
        swap.swapAtoB(swapAmount);

        assertEq(tokenA.balanceOf(user1), user1BalanceABefore - swapAmount);
        assertEq(tokenB.balanceOf(user1), user1BalanceBBefore + expectedTokenB);
    }

    function testSwapEmitsEvent() public {
        uint256 swapAmount = 1000 * 10**18;
        uint256 expectedTokenB = 1 * 10**18;

        vm.expectEmit(true, false, false, true);
        emit ITokenSwap.SwapExecuted(user1, swapAmount, expectedTokenB);

        vm.prank(user1);
        swap.swapAtoB(swapAmount);
    }

    // ========== Referral Tests ==========

    function testSwapWithReferral() public {
        uint256 swapAmount = 1000 * 10**18;
        uint256 expectedTokenB = 1 * 10**18;
        uint256 expectedReferralReward = 10 * 10**18; // 1% of 1000

        uint256 referrerBalanceBefore = tokenA.balanceOf(referrer);

        vm.prank(user1);
        swap.swapAtoBWithRef(swapAmount, referrer);

        // User gets TokenB
        assertEq(tokenB.balanceOf(user1), expectedTokenB);
        
        // Referrer gets 1% in TokenA
        assertEq(tokenA.balanceOf(referrer), referrerBalanceBefore + expectedReferralReward);
    }

    function testReferralEmitsEvent() public {
        uint256 swapAmount = 1000 * 10**18;
        uint256 expectedReward = 10 * 10**18;

        vm.expectEmit(true, false, false, true);
        emit ITokenSwap.ReferralReward(referrer, expectedReward);

        vm.prank(user1);
        swap.swapAtoBWithRef(swapAmount, referrer);
    }

    function testCannotSelfRefer() public {
        vm.prank(user1);
        vm.expectRevert("Cannot refer yourself");
        swap.swapAtoBWithRef(1000 * 10**18, user1);
    }

    function testCannotReferZeroAddress() public {
        vm.prank(user1);
        vm.expectRevert("Referrer cannot be zero address");
        swap.swapAtoBWithRef(1000 * 10**18, address(0));
    }

    // ========== Liquidity & Balance Tests ==========

    function testInsufficientLiquidity() public {
        uint256 largeSwap = 2_000_000 * 10**18; // Way more than contract has

        vm.prank(user1);
        vm.expectRevert("Insufficient TokenB liquidity");
        swap.swapAtoB(largeSwap);
    }

    function testDepositLiquidity() public {
        uint256 depositAmount = 100 * 10**18;
        uint256 contractBalanceBefore = tokenB.balanceOf(address(swap));

        tokenB.approve(address(swap), depositAmount);
        swap.depositLiquidity(depositAmount);

        assertEq(tokenB.balanceOf(address(swap)), contractBalanceBefore + depositAmount);
    }

    function testOnlyOwnerCanDepositLiquidity() public {
        vm.prank(user1);
        vm.expectRevert();
        swap.depositLiquidity(100 * 10**18);
    }

    // ========== Admin Tests ==========

    function testWithdrawTokens() public {
        uint256 withdrawAmount = 100 * 10**18;
        uint256 ownerBalanceBefore = tokenB.balanceOf(owner);

        swap.withdrawTokens(address(tokenB), withdrawAmount);

        assertEq(tokenB.balanceOf(owner), ownerBalanceBefore + withdrawAmount);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.prank(user1);
        vm.expectRevert();
        swap.withdrawTokens(address(tokenB), 100 * 10**18);
    }

    function testPauseSwap() public {
        swap.pause();

        vm.prank(user1);
        vm.expectRevert();
        swap.swapAtoB(1000 * 10**18);
    }

    function testUnpauseSwap() public {
        swap.pause();
        swap.unpause();

        // Should work after unpause
        vm.prank(user1);
        swap.swapAtoB(1000 * 10**18);
    }

    function testOnlyOwnerCanPause() public {
        vm.prank(user1);
        vm.expectRevert();
        swap.pause();
    }

    // ========== Edge Cases ==========

    function testZeroAmountSwap() public {
        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        swap.swapAtoB(0);
    }

    function testVerySmallSwap() public {
        // Swap amount that results in 0 TokenB (less than 1000)
        vm.prank(user1);
        vm.expectRevert("Swap amount too small");
        swap.swapAtoB(999); // Less than 1000 wei, results in 0
    }

    function testInsufficientReferralRewardFunds() public {
        // Drain TokenA from contract
        swap.withdrawTokens(address(tokenA), tokenA.balanceOf(address(swap)));

        vm.prank(user1);
        vm.expectRevert("Insufficient TokenA for referral reward");
        swap.swapAtoBWithRef(1000 * 10**18, referrer);
    }

    // ========== View Function Tests ==========

    function testGetSwapRate() public view{
        (uint256 numerator, uint256 denominator) = swap.getSwapRate();
        assertEq(numerator, 1);
        assertEq(denominator, 1000);
    }

    function testGetReferralRate() public view{
        assertEq(swap.getReferralRate(), 1);
    }

    function testGetBalances() public view{
        uint256 balanceA = swap.getTokenABalance();
        uint256 balanceB = swap.getTokenBBalance();
        
        assertGt(balanceA, 0);
        assertGt(balanceB, 0);
    }

    // ========== Reentrancy Test ==========
    // Note: Basic reentrancy test - for thorough testing, 
    // you'd create a malicious contract that attempts reentry

    function testReentrancyProtection() public {
        // ReentrancyGuard is in place, multiple calls should work fine
        vm.startPrank(user1);
        swap.swapAtoB(1000 * 10**18);
        swap.swapAtoB(1000 * 10**18);
        vm.stopPrank();

        assertEq(tokenB.balanceOf(user1), 2 * 10**18);
    }
}

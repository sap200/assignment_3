// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {TokenSwap} from "../src/TokenSwap.sol";
import {TokenA} from "../src/TokenA.sol";
import {TokenB} from "../src/TokenB.sol";


contract TokenSwapTest is Test {

    TokenA public tokenA;
    TokenB public tokenB;
    TokenSwap public tokenSwap;
    uint256 public constant FIXED_EXCHANGE_RATE = 15; // 1 tokenA = 15 tokenB
    address public accountA;
    address public accountB;
    

    function setUp() public {
        tokenA = new TokenA();
        tokenB = new TokenB();
        tokenSwap = new TokenSwap(tokenA, tokenB, FIXED_EXCHANGE_RATE);
        accountA = vm.addr(1);
        accountB = vm.addr(2);
        vm.deal(accountA, 100 ether);
        vm.deal(accountB, 100 ether);
        tokenA.mint(accountA, 1000 * 10**18);
        tokenB.mint(accountB, 1000 * 10**18);
        // MINT 1 million token in tokenSwap's reserve
        tokenA.mint(address(tokenSwap), 1000000 * 10**18);
        tokenB.mint(address(tokenSwap), 1000000 * 10**18);
    }

    // TestDescription: accountA swaps 10 tokenA for tokenB
    // Expected: accountA receives 150 tokenB and tokenSwap's reserve has 1000010 token A after transaction execution
    function testFuzz_swapAForB(uint256 x) public {
        uint256 randomExchangeRate = x % 20 + 1;
        tokenSwap.setExchangeRate(randomExchangeRate);
        // track initial state
        uint256 initialBalanceOfTokenAInAccountA = tokenA.balanceOf(accountA);
        uint256 initialBalanceOfTokenBInAccountA = tokenB.balanceOf(accountA);
        uint256 initialBalanceOfTokenAInTokenSwapContract = tokenA.balanceOf(address(tokenSwap));
        uint256 initialBalanceOfTokenBInTokenSwapContract = tokenB.balanceOf(address(tokenSwap));

        // swap
        uint256 amountOfTokenA = 10 * 1 ether; // 1 ether = 10**18
        // provide tokenAllowance
        vm.prank(accountA);
        tokenA.approve(address(tokenSwap), amountOfTokenA);
        vm.expectEmit(true, true, true, true, address(tokenSwap));
        emit TokenSwap.Swapped(accountA, address(tokenA), address(tokenB), amountOfTokenA, randomExchangeRate*amountOfTokenA, 0);
        vm.prank(accountA);
        tokenSwap.swapAForB(amountOfTokenA);

        // track final state
        uint256 finalBalanceOfTokenAInAccountA = tokenA.balanceOf(accountA);
        uint256 finalBalanceOfTokenBInAccountA = tokenB.balanceOf(accountA);
        uint256 finalBalanceOfTokenAInTokenSwapContract = tokenA.balanceOf(address(tokenSwap));
        uint256 finalBalanceOfTokenBInTokenSwapContract = tokenB.balanceOf(address(tokenSwap));

        assertEq(finalBalanceOfTokenAInAccountA, initialBalanceOfTokenAInAccountA - amountOfTokenA);
        assertEq(finalBalanceOfTokenBInAccountA, initialBalanceOfTokenBInAccountA + randomExchangeRate*amountOfTokenA);
        assertEq(finalBalanceOfTokenAInTokenSwapContract, initialBalanceOfTokenAInTokenSwapContract + amountOfTokenA);
        assertEq(finalBalanceOfTokenBInTokenSwapContract, initialBalanceOfTokenBInTokenSwapContract - randomExchangeRate*amountOfTokenA);
    }

    // TestDescription: accountA sends 0 tokenA for swapping with tokenB
    // Expected: VM reverts the txn with an error
    function test_SwapAForBWithZeroTokenA() public {
        vm.expectRevert("swapping 0 tokens not allowed");
        vm.prank(accountA);
        tokenSwap.swapAForB(0);
    }

    // TestDescription: accountA tries to swap more tokenA than available in his account balance
    // Expected: VM reverts with an error
    function test_SwapAForBWithMoreTokenARequestedThanAvailable() public {
        vm.expectRevert("Insufficient token A in msg senders account");
        vm.prank(accountA);
        tokenSwap.swapAForB(5000 * 1 ether);
    }

    // TestDescription: accountA tries to swap tokenA for tokenB but has not provided enough allowance as requested to token swap smart contract
    // Expected: VM reverts with an error
    function test_swapAForBWithInsufficientAllowance() public {
        tokenA.approve(address(tokenSwap), 100 * 1 ether);
        vm.expectRevert("TokenA allowance too low");
        vm.prank(accountA);
        tokenSwap.swapAForB(500 * 1 ether);
    }

    // TestDescription: accountA tries to swap tokenA for tokenB but the tokenswap contract doesn't have sufficient amount of tokenB in the reserve
    // Expected: VM reverts with an error
    function test_swapAForBInsufficientTokenBInReserve() public {
        tokenA.mint(accountA, 1000000 * 1 ether);
        vm.prank(accountA);
        tokenA.approve(address(tokenSwap), 1000000 * 1 ether);
        vm.expectRevert("Insufficient balance of TokenB in the reserve");
        vm.prank(accountA);
        tokenSwap.swapAForB(1000000 * 1 ether);
    }

    // TestDescription: accountB swaps 25 tokenB for tokenA
    // Expected: As per exchange rate send maximum tokenA to accountB and refund remaining tokenB to accountA
    function testFuzz_swapBForA(uint256 x) public {
        uint256 randomExchangeRate = x % 20 + 1;
        tokenSwap.setExchangeRate(randomExchangeRate);

        // track initial state
        uint256 initialBalanceOfTokenAInAccountB = tokenA.balanceOf(accountB);
        uint256 initialBalanceOfTokenBInAccountB = tokenB.balanceOf(accountB);
        uint256 initialBalanceOfTokenAInTokenSwapContract = tokenA.balanceOf(address(tokenSwap));
        uint256 initialBalanceOfTokenBInTokenSwapContract = tokenB.balanceOf(address(tokenSwap));

        // swap
        uint256 amountOfTokenB = 25 * 1 ether; // 1 ether = 10**18
        uint256 expRefundedAmount = amountOfTokenB % randomExchangeRate;
        uint256 expAmountOfTokenA = amountOfTokenB / randomExchangeRate;
        // provide tokenAllowance
        vm.prank(accountB);
        tokenB.approve(address(tokenSwap), amountOfTokenB);
        vm.expectEmit(true, true, true, true, address(tokenSwap));
        emit TokenSwap.Swapped(accountB, address(tokenB), address(tokenA), amountOfTokenB, expAmountOfTokenA, expRefundedAmount);
        vm.prank(accountB);
        tokenSwap.swapBForA(amountOfTokenB);

        // track final state
        uint256 finalBalanceOfTokenAInAccountB = tokenA.balanceOf(accountB);
        uint256 finalBalanceOfTokenBInAccountB = tokenB.balanceOf(accountB);
        uint256 finalBalanceOfTokenAInTokenSwapContract = tokenA.balanceOf(address(tokenSwap));
        uint256 finalBalanceOfTokenBInTokenSwapContract = tokenB.balanceOf(address(tokenSwap));

        assertEq(finalBalanceOfTokenAInAccountB, initialBalanceOfTokenAInAccountB + expAmountOfTokenA);
        assertEq(finalBalanceOfTokenBInAccountB, initialBalanceOfTokenBInAccountB - amountOfTokenB + expRefundedAmount);
        assertEq(finalBalanceOfTokenAInTokenSwapContract, initialBalanceOfTokenAInTokenSwapContract - expAmountOfTokenA);
        assertEq(finalBalanceOfTokenBInTokenSwapContract, initialBalanceOfTokenBInTokenSwapContract + amountOfTokenB - expRefundedAmount);
    }

    // TestDescription: accountB sends 0 tokenB for swapping with tokenA
    // Expected: VM reverts the txn with an error
    function test_SwapBForAWithZeroTokenA() public {
        vm.expectRevert("swapping 0 tokens not allowed");
        vm.prank(accountB);
        tokenSwap.swapBForA(0);
    }

    // TestDescription: accountB tries to swap more tokenB than available in his account balance
    // Expected: VM reverts with an error
    function test_SwapBForAWithMoreTokenBRequestedThanAvailable() public {
        vm.expectRevert("Insufficient tokenB in msg sender's account");
        vm.prank(accountB);
        tokenSwap.swapBForA(5000 * 1 ether);
    }

    // TestDescription: accountB tries to swap tokenB for tokenA but has not provided enough allowance as requested to token swap smart contract
    // Expected: VM reverts with an error
    function test_swapBForAWithInsufficientAllowance() public {
        tokenB.approve(address(tokenSwap), 100 * 1 ether);
        vm.expectRevert("TokenB allowance too low");
        vm.prank(accountB);
        tokenSwap.swapBForA(500 * 1 ether);
    }

    // TestDescription: accountB tries to swap tokenB for tokenA but the tokenswap contract doesn't have sufficient amount of tokenA in the reserve
    // Expected: VM reverts with an error
    function test_swapBForAInsufficientTokenBInReserve() public {
        tokenB.mint(accountB, 100000000 * 1 ether);
        vm.prank(accountB);
        tokenB.approve(address(tokenSwap), 100000000 * 1 ether);
        vm.expectRevert("Insufficient balance of TokenA in the reserve");
        vm.prank(accountB);
        tokenSwap.swapBForA(100000000 * 1 ether);
    }
}
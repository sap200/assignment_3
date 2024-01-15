// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
 * I am considering Token Swap has a reserve of A and B initially and swap takes place based on the reserve
 */

contract TokenSwap is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public fixedExchangeRate; // exchange rate is defined as 1 token A = X token B

    event Swapped(
        address indexed user,
        address indexed fromTokenContract,
        address indexed toTokenContract,
        uint256 fromTokenAmount,
        uint256 toTokenAmount,
        uint256 refundAmount
    );

    constructor(
        IERC20 _tokenA,
        IERC20 _tokenB,
        uint256 _fixedExchangeRate
    ) Ownable(msg.sender) {
        require(
            _fixedExchangeRate > 0,
            "Fixed exchange rate should be greater than 0"
        );
        tokenA = _tokenA;
        tokenB = _tokenB;
        fixedExchangeRate = _fixedExchangeRate;
    }

    function swapAForB(uint256 amountOfA) external {
        require(amountOfA > 0, "swapping 0 tokens not allowed");
        // Ensure user has requested amount of TokenA in his balance
        require(
            tokenA.balanceOf(msg.sender) >= amountOfA,
            "Insufficient token A in msg senders account"
        );
        require(
            tokenA.allowance(msg.sender, address(this)) >= amountOfA,
            "TokenA allowance too low"
        );
        uint256 amountOfB = amountOfA.mul(fixedExchangeRate);
        require(
            tokenB.balanceOf(address(this)) >= amountOfB,
            "Insufficient balance of TokenB in the reserve"
        );
        tokenA.safeTransferFrom(msg.sender, address(this), amountOfA);
        tokenB.safeTransfer(msg.sender, amountOfB);

        // No excess Remainder since it's a pure multiplication

        emit Swapped(
            msg.sender,
            address(tokenA),
            address(tokenB),
            amountOfA,
            amountOfB,
            0
        );
    }

    function swapBForA(uint256 amountOfB) external {
        require(amountOfB > 0, "swapping 0 tokens not allowed");
        // Ensure user has requested amount of TokenB in his balance
        require(
            tokenB.balanceOf(msg.sender) >= amountOfB,
            "Insufficient tokenB in msg sender's account"
        );
        require(
            tokenB.allowance(msg.sender, address(this)) >= amountOfB,
            "TokenB allowance too low"
        );
        uint256 amountOfA = amountOfB.div(fixedExchangeRate);
        uint256 excessRemainderOfB = amountOfB.mod(fixedExchangeRate);
        // additional check to ensure non-zero amount of A
        require(amountOfA > 0, "Swapping 0 tokens not allowed");
        require(
            tokenA.balanceOf(address(this)) >= amountOfA,
            "Insufficient balance of TokenA in the reserve"
        );

        // transfer tokenB to contract's address
        tokenB.safeTransferFrom(msg.sender, address(this), amountOfB);
        tokenA.safeTransfer(msg.sender, amountOfA);

        // process refund
        if (excessRemainderOfB > 0) {
            tokenB.safeTransfer(msg.sender, excessRemainderOfB);
        }

        emit Swapped(
            msg.sender,
            address(tokenB),
            address(tokenA),
            amountOfB,
            amountOfA,
            excessRemainderOfB
        );
    }

    // This function is for testing purpose so that the exchange rate can be fuzzed
    // and different exchange rate can be used
    function setExchangeRate(uint256 _exchangeRate) external onlyOwner {
        fixedExchangeRate = _exchangeRate;
    }
}

// contracts/MockSwapRouter.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Burnable is IERC20 {
    function burn(uint256 amount) external;
}

contract MockSwapRouter {
    IERC20 public immutable idrxToken;
    uint256 public constant EXCHANGE_RATE = 100; // 1 tokenIn = 100 IDRX

    event SwapExecuted(address indexed tokenIn, address indexed recipient, uint256 amountIn, uint256 amountOut);

    constructor(address _idrxAddress) {
        idrxToken = IERC20(_idrxAddress);
    }

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256 amountOut) {
        require(params.tokenOut == address(idrxToken), "Only IDRX swaps supported in mock");
        require(params.amountOutMinimum <= params.amountIn * EXCHANGE_RATE, "Slippage too high in mock");

        // Simulate transfer of tokenIn from caller (gateway) to this router (burn it)
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        // Assume tokenIn is burnable, or just hold it
        // For simplicity, we don't burn, but in real mock, could transfer to dead address

        // Mint or transfer IDRX to recipient
        amountOut = params.amountIn * EXCHANGE_RATE;
        idrxToken.transfer(params.recipient, amountOut);

        emit SwapExecuted(params.tokenIn, params.recipient, params.amountIn, amountOut);

        return amountOut;
    }

    // Helper to mint IDRX for liquidity simulation (call from test)
    function mintIdrx(address to, uint256 amount) external {
        idrxToken.transfer(to, amount); // But since idrx is mock, need mint in test
    }
}
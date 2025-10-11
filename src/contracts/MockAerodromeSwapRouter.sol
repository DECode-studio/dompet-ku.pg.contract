// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Struct Route dari Aerodrome (untuk path)
struct Route {
    address from;
    address to;
    bool stable;
    address factory;
}

// Interface Aerodrome Router
interface IAerodromeRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Route[] calldata routes, // Path sebagai array Route
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract MockAerodromeSwapRouter is IAerodromeRouter {
    IERC20 public immutable idrxToken;
    uint256 public constant EXCHANGE_RATE = 100; // 1 tokenIn = 100 IDRX (mock rate)
    address public constant MOCK_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da; // Mock Aerodrome factory

    event SwapExecuted(address indexed tokenIn, address indexed recipient, uint256 amountIn, uint256 amountOut);

    constructor(address _idrxAddress) {
        idrxToken = IERC20(_idrxAddress);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Route[] calldata routes,
        address to,
        uint deadline
    ) external override returns (uint[] memory amounts) {
        require(block.timestamp <= deadline, "Mock: Transaction expired");
        require(routes.length == 1, "Mock: Only single route supported");
        Route memory route = routes[0];
        require(route.from != address(0) && route.to != address(0), "Mock: Invalid route");
        require(route.factory == MOCK_FACTORY, "Mock: Invalid factory"); // Optional check

        // Simulate transfer of tokenIn from caller (gateway) to this router (hold/burn)
        IERC20(route.from).transferFrom(msg.sender, address(this), amountIn);

        // Calculate output based on exchange rate
        uint256 amountOut = amountIn * EXCHANGE_RATE;
        require(amountOut >= amountOutMin, "Mock: Slippage too high");

        // Transfer IDRX to recipient from liquidity (assume pre-minted to mock)
        idrxToken.transfer(to, amountOut);

        emit SwapExecuted(route.from, to, amountIn, amountOut);

        // Return amounts array
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        return amounts;
    }

    // Helper for tests: Mint IDRX to this mock for liquidity simulation
    function mintIdrx(address to, uint256 amount) external {
        idrxToken.transfer(to, amount);
    }
}
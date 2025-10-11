// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Struct PoolKey dari Aerodrome (untuk path)
struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
}

// Interface Aerodrome Router
interface IAerodromeRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        PoolKey[] calldata pools, // Path sebagai array PoolKey (bukan address[])
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract MockAerodromeSwapRouter is IAerodromeRouter {
    IERC20 public immutable idrxToken;
    uint256 public constant EXCHANGE_RATE = 100; // 1 tokenIn = 100 IDRX (mock rate)

    event SwapExecuted(address indexed tokenIn, address indexed recipient, uint256 amountIn, uint256 amountOut);

    constructor(address _idrxAddress) {
        idrxToken = IERC20(_idrxAddress);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        PoolKey[] calldata pools,
        address to,
        uint deadline
    ) external override returns (uint[] memory amounts) {
        require(block.timestamp <= deadline, "Mock: Transaction expired");
        require(pools.length == 1, "Mock: Only single pool supported");
        PoolKey memory pool = pools[0];
        require(pool.currency0 != address(0) && pool.currency1 != address(0), "Mock: Invalid pool");
        require(pool.fee > 0, "Mock: Fee must be >0");

        // Simulate transfer of tokenIn from caller (gateway) to this router (hold/burn)
        IERC20(pool.currency0).transferFrom(msg.sender, address(this), amountIn);

        // Calculate output based on exchange rate
        uint256 amountOut = amountIn * EXCHANGE_RATE;
        require(amountOut >= amountOutMin, "Mock: Slippage too high");

        // Transfer IDRX to recipient from liquidity (assume pre-minted to mock)
        idrxToken.transfer(to, amountOut);

        emit SwapExecuted(pool.currency0, to, amountIn, amountOut);

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
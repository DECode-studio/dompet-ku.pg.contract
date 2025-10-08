// contracts/mocks/MockUniswapV2Router.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapV2Router {
    // Simulasi kurs: 1 tokenIn = 100 tokenOut (misal: 1 USDT = 100 IDRX)
    uint256 private constant EXCHANGE_RATE = 100;

    // Alamat token yang akan 'disediakan' oleh router ini
    address public idrxAddress;

    constructor(address _idrx) {
        idrxAddress = _idrx;
    }

    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external pure returns (uint[] memory amounts) {
        require(path.length == 2, "MockRouter: Invalid path");
        amounts = new uint[](2);
        amounts[1] = amountOut;
        // Berdasarkan kurs, hitung jumlah token input yang diperlukan
        amounts[0] = amountOut / EXCHANGE_RATE;
        return amounts;
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint
    ) external returns (uint[] memory amounts) {
        require(path.length == 2, "MockRouter: Invalid path");

        address tokenInAddress = path[0];
        address tokenOutAddress = path[1];

        require(
            tokenOutAddress == idrxAddress,
            "MockRouter: Can only swap for IDRX"
        );

        uint amountIn = amountOut / EXCHANGE_RATE;
        require(
            amountInMax >= amountIn,
            "MockRouter: INSUFFICIENT_INPUT_AMOUNT"
        );

        // 1. Tarik token input dari pengirim (yaitu kontrak SmartIdrxSender)
        IERC20(tokenInAddress).transferFrom(
            msg.sender,
            address(this),
            amountIn
        );

        // 2. Kirim token output ke penerima akhir
        IERC20(tokenOutAddress).transfer(to, amountOut);

        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        return amounts;
    }
}

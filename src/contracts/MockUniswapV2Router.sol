// contracts/mocks/MockUniswapV2Router.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapV2Router {
    // Simulasi kurs: 1 tokenIn akan menghasilkan 100 tokenOut (misal: 1 USDT = 100 IDRX)
    uint256 private constant EXCHANGE_RATE = 100;

    // Alamat token yang akan 'disediakan' oleh router ini (misalnya IDRX)
    address public immutable idrxAddress;

    constructor(address _idrxAddress) {
        idrxAddress = _idrxAddress;
    }

    /**
     * @dev Mensimulasikan swap dengan jumlah token INPUT yang pasti.
     * Ini adalah fungsi yang paling umum digunakan untuk swap.
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin, // Diabaikan di mock, tapi harus ada untuk mencocokkan interface
        address[] calldata path,
        address to,
        uint // deadline (juga diabaikan)
    ) external returns (uint[] memory amounts) {
        // Mencegah error "unused parameter" saat kompilasi
        amountOutMin; 
        
        require(path.length == 2, "MockRouter: Invalid path");
        address tokenInAddress = path[0];
        address tokenOutAddress = path[1];

        require(tokenOutAddress == idrxAddress, "MockRouter: Can only swap for IDRX");
        
        // 1. Hitung jumlah token output berdasarkan kurs
        uint amountOut = amountIn * EXCHANGE_RATE;

        // 2. Tarik token input dari pengirim (misalnya kontrak PaymentGateway)
        IERC20(tokenInAddress).transferFrom(msg.sender, address(this), amountIn);

        // 3. Kirim token output (IDRX) ke penerima akhir
        IERC20(tokenOutAddress).transfer(to, amountOut);

        // 4. Kembalikan jumlah input dan output, sesuai perilaku Uniswap
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        return amounts;
    }
    
    /**
     * @dev Mensimulasikan swap dengan jumlah token OUTPUT yang pasti.
     */
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint // deadline
    ) external returns (uint[] memory amounts) {
        require(path.length == 2, "MockRouter: Invalid path");
        address tokenInAddress = path[0];
        address tokenOutAddress = path[1];

        require(tokenOutAddress == idrxAddress, "MockRouter: Can only swap for IDRX");

        // Hitung jumlah input yang dibutuhkan
        uint amountIn = amountOut / EXCHANGE_RATE;
        require(amountInMax >= amountIn, "MockRouter: INSUFFICIENT_INPUT_AMOUNT");

        IERC20(tokenInAddress).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOutAddress).transfer(to, amountOut);

        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        return amounts;
    }

    /**
     * @dev Mensimulasikan perhitungan jumlah input yang dibutuhkan.
     */
    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external pure returns (uint[] memory amounts) {
        require(path.length == 2, "MockRouter: Invalid path");
        amounts = new uint[](2);
        amounts[1] = amountOut;
        amounts[0] = amountOut / EXCHANGE_RATE;
        return amounts;
    }
}
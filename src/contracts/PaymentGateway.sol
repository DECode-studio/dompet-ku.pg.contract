// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// Antarmuka standar untuk token ERC20
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

// Antarmuka untuk Uniswap V2 Router
interface IUniswapV2Router02 {
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

/**
 * @title PaymentGateway
 * @dev Kontrak ini memungkinkan pengiriman IDRX. Jika saldo IDRX tidak cukup,
 * kontrak akan secara otomatis menukar USDT atau USDC pengguna untuk menutupi kekurangan.
 * PENTING: Pengguna HARUS memberikan 'approval' kepada kontrak ini untuk dapat
 * mengakses token IDRX, USDT, dan USDC mereka sebelum menjalankan transfer.
 */
contract PaymentGateway {

    // --- State Variables ---

    address public immutable owner;
    IERC20 public immutable idrxToken;
    IERC20 public immutable usdtToken;
    IERC20 public immutable usdcToken;
    IUniswapV2Router02 public immutable uniswapRouter;

    // --- Event ---

    event TransferFromDuitku(
        address indexed from,
        address indexed to,
        uint256 amount,
        bool isSwapped,
        address swappedToken,
        uint256 swappedAmountIn
    );

    // --- Constructor ---

    /**
     * @param _idrxAddress Alamat kontrak token IDRX.
     * @param _usdtAddress Alamat kontrak token USDT.
     * @param _usdcAddress Alamat kontrak token USDC.
     * @param _routerAddress Alamat kontrak Uniswap V2 Router.
     */
    constructor(
        address _idrxAddress,
        address _usdtAddress,
        address _usdcAddress,
        address _routerAddress
    ) {
        owner = msg.sender;
        idrxToken = IERC20(_idrxAddress);
        usdtToken = IERC20(_usdtAddress);
        usdcToken = IERC20(_usdcAddress);
        uniswapRouter = IUniswapV2Router02(_routerAddress);
    }

    // --- Public Functions ---

    /**
     * @notice Mengirimkan IDRX ke alamat tujuan.
     * @dev Jika saldo IDRX `msg.sender` cukup, akan langsung melakukan transfer.
     * Jika tidak, akan menghitung kekurangan, menukarkannya dari USDT atau USDC,
     * dan mengirimkan totalnya ke tujuan.
     * @param _to Alamat penerima.
     * @param _amount Jumlah IDRX yang ingin dikirim.
     */
    function transfer(address _to, uint256 _amount) external {
        require(_to != address(0), "Transfer to the zero address");
        require(_amount > 0, "Transfer amount must be greater than zero");

        uint256 senderIdrxBalance = idrxToken.balanceOf(msg.sender);

        // Skenario 1: Saldo IDRX mencukupi
        if (senderIdrxBalance >= _amount) {
            // Langsung transfer IDRX dari pengguna ke penerima
            idrxToken.transferFrom(msg.sender, _to, _amount);
            emit TransferFromDuitku(msg.sender, _to, _amount, false, address(0), 0);
        }
        // Skenario 2: Saldo IDRX tidak cukup, perlu swap
        else {
            uint256 amountToSwap = _amount - senderIdrxBalance;

            // Jika ada saldo IDRX awal, transfer dulu
            if (senderIdrxBalance > 0) {
                idrxToken.transferFrom(msg.sender, _to, senderIdrxBalance);
            }

            // Lakukan swap untuk menutupi kekurangan
            (address tokenUsed, uint256 amountIn) = _swapForIdrx(amountToSwap, _to);

            emit TransferFromDuitku(msg.sender, _to, _amount, true, tokenUsed, amountIn);
        }
    }


    // --- Private Functions ---

    /**
     * @dev Fungsi internal untuk melakukan swap dari USDT atau USDC ke IDRX.
     * Prioritas pertama adalah USDT, jika tidak cukup, akan mencoba USDC.
     * @param _idrxAmountOut Jumlah IDRX yang dibutuhkan dari hasil swap.
     * @param _recipient Alamat penerima akhir dari IDRX hasil swap.
     * @return tokenUsed Alamat token yang digunakan untuk swap (USDT/USDC).
     * @return amountIn Jumlah token yang ditarik dari pengguna untuk swap.
     */
    function _swapForIdrx(uint256 _idrxAmountOut, address _recipient) private returns (address tokenUsed, uint256 amountIn) {
        // Coba swap menggunakan USDT terlebih dahulu
        if (usdtToken.balanceOf(msg.sender) > 0 && usdtToken.allowance(msg.sender, address(this)) > 0) {
            bool success = _executeSwap(usdtToken, _idrxAmountOut, _recipient);
            if (success) {
                // Kalkulasi amountIn yang dibutuhkan untuk event log
                address[] memory path = new address[](2);
                path[0] = address(usdtToken);
                path[1] = address(idrxToken);
                uint[] memory amounts = uniswapRouter.getAmountsIn(_idrxAmountOut, path);
                return (address(usdtToken), amounts[0]);
            }
        }

        // Jika USDT gagal atau tidak cukup, coba USDC
        if (usdcToken.balanceOf(msg.sender) > 0 && usdcToken.allowance(msg.sender, address(this)) > 0) {
             bool success = _executeSwap(usdcToken, _idrxAmountOut, _recipient);
             if (success) {
                address[] memory path = new address[](2);
                path[0] = address(usdcToken);
                path[1] = address(idrxToken);
                uint[] memory amounts = uniswapRouter.getAmountsIn(_idrxAmountOut, path);
                return (address(usdcToken), amounts[0]);
            }
        }
        
        revert("Insufficient balance in USDT/USDC or approval not set");
    }

    /**
     * @dev Mengeksekusi swap di Uniswap V2.
     */
    function _executeSwap(IERC20 _tokenIn, uint256 _amountOut, address _recipient) private returns (bool) {
        address[] memory path = new address[](2);
        path[0] = address(_tokenIn);
        path[1] = address(idrxToken);

        // Menghitung berapa banyak token input (USDT/USDC) yang dibutuhkan
        uint[] memory amountsIn = uniswapRouter.getAmountsIn(_amountOut, path);
        uint256 requiredAmountIn = amountsIn[0];

        // Memeriksa apakah saldo dan allowance pengguna mencukupi
        if (_tokenIn.balanceOf(msg.sender) < requiredAmountIn) return false;
        if (_tokenIn.allowance(msg.sender, address(this)) < requiredAmountIn) return false;

        // 1. Tarik token (USDT/USDC) dari pengguna ke kontrak ini
        _tokenIn.transferFrom(msg.sender, address(this), requiredAmountIn);

        // 2. Kontrak ini memberikan approval ke Uniswap Router
        _tokenIn.approve(address(uniswapRouter), requiredAmountIn);

        // 3. Lakukan swap. Hasil IDRX langsung dikirim ke penerima akhir (_recipient)
        uniswapRouter.swapTokensForExactTokens(
            _amountOut,         // Jumlah output (IDRX) yang pasti didapat
            requiredAmountIn,   // Jumlah input maksimum yang rela dibayar
            path,
            _recipient,         // Penerima hasil swap
            block.timestamp     // Deadline transaksi
        );
        
        return true;
    }
}
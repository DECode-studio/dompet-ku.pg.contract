// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

//
interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);
}

struct Route {
    address from;
    address to;
    bool stable;
    address factory;
}

interface IAerodromeRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

/**
 * @title PaymentGatewayAerodromeUniversal
 * @author (Your Name)
 * @notice Kontrak ini berfungsi sebagai gateway pembayaran yang dapat menerima
 * token yang didukung dan menukarnya (swap) menjadi token IDRX
 * secara otomatis melalui Aerodrome Finance di jaringan Base.
 */
contract PaymentGatewayAerodromeRouter is Ownable {
    IERC20 public immutable idrxToken;
    IAerodromeRouter public immutable aerodromeRouter;
    address public constant AERODROME_FACTORY =
        0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    mapping(address => bool) public isSupportedToken;
    mapping(address => bool) public tokenUsesStablePool;

    address[] public supportedTokens;
    event PaymentProcessed(
        address indexed from,
        address indexed to,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOutIdrx,
        bool isSwapped
    );

    event SupportedTokenAdded(address indexed token, bool isStablePool);
    event SupportedTokenRemoved(address indexed token);
    event TokenPoolTypeUpdated(address indexed token, bool isStablePool);

    /**
     * @notice Men-deploy kontrak dan menginisialisasi parameter utama.
     * @param _idrxAddress Alamat kontrak token IDRX.
     * @param _aerodromeRouterAddress Alamat Aerodrome Router V2 di Base.
     * @param _initialSupportedTokens Array alamat token yang didukung saat deploy.
     * @param _initialIsStable Array boolean yang sesuai, `true` jika pool token tsb adalah stable.
     */
    constructor(
        address _idrxAddress,
        address _aerodromeRouterAddress,
        address[] memory _initialSupportedTokens,
        bool[] memory _initialIsStable
    ) Ownable(msg.sender) {
        require(
            _idrxAddress != address(0) && _aerodromeRouterAddress != address(0),
            "Zero address"
        );
        require(
            _initialSupportedTokens.length == _initialIsStable.length,
            "Mismatched initial arrays"
        );

        idrxToken = IERC20(_idrxAddress);
        aerodromeRouter = IAerodromeRouter(_aerodromeRouterAddress);

        for (uint i = 0; i < _initialSupportedTokens.length; i++) {
            _addToken(_initialSupportedTokens[i], _initialIsStable[i]);
        }
    }

    /**
     * @notice Fungsi utama yang dipanggil pengguna untuk memproses pembayaran.
     * @dev Jika token input adalah IDRX, token hanya diteruskan. Jika token lain yang
     * didukung, maka akan di-swap terlebih dahulu.
     * @param _tokenIn Alamat token yang dikirim oleh pengguna.
     * @param _to Alamat penerima akhir token IDRX.
     * @param _amountIn Jumlah token yang dikirim.
     */
    function transfer(
        address _tokenIn,
        address _to,
        uint256 _amountIn
    ) external {
        require(_to != address(0), "Transfer to the zero address");
        require(_amountIn > 0, "Amount must be greater than zero");

        if (_tokenIn == address(idrxToken)) {
            idrxToken.transferFrom(msg.sender, _to, _amountIn);
            emit PaymentProcessed(
                msg.sender,
                _to,
                _tokenIn,
                _amountIn,
                _amountIn,
                false
            );
        } else if (isSupportedToken[_tokenIn]) {
            _swapAndSend(IERC20(_tokenIn), _to, _amountIn);
        } else {
            revert("Token not supported");
        }
    }

    /**
     * @notice Logika internal untuk melakukan swap.
     */
    function _swapAndSend(
        IERC20 _tokenIn,
        address _recipient,
        uint256 _amountIn
    ) private {
        _tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        _tokenIn.approve(address(aerodromeRouter), _amountIn);

        Route[] memory routes = new Route[](1);
        routes[0] = Route({
            from: address(_tokenIn),
            to: address(idrxToken),
            stable: tokenUsesStablePool[address(_tokenIn)],
            factory: AERODROME_FACTORY
        });

        uint[] memory amountsOut = aerodromeRouter.swapExactTokensForTokens(
            _amountIn,
            0,
            routes,
            _recipient,
            block.timestamp + 300
        );

        uint256 idrxReceived = amountsOut[amountsOut.length - 1];

        emit PaymentProcessed(
            msg.sender,
            _recipient,
            address(_tokenIn),
            _amountIn,
            idrxReceived,
            true
        );
    }

    /**
     * @notice Logika internal untuk menambahkan token, digunakan oleh constructor dan fungsi owner.
     */
    function _addToken(address _tokenAddress, bool _isStablePool) private {
        require(
            _tokenAddress != address(0) && _tokenAddress != address(idrxToken),
            "Invalid token address"
        );
        require(!isSupportedToken[_tokenAddress], "Token already supported");

        isSupportedToken[_tokenAddress] = true;
        tokenUsesStablePool[_tokenAddress] = _isStablePool;
        supportedTokens.push(_tokenAddress);

        emit SupportedTokenAdded(_tokenAddress, _isStablePool);
    }

    /**
     * @notice Menambahkan token baru yang didukung.
     * @param _tokenAddress Alamat token yang akan ditambahkan.
     * @param _isStablePool `true` jika pool swap-nya adalah stable pool.
     */
    function addSupportedToken(
        address _tokenAddress,
        bool _isStablePool
    ) external onlyOwner {
        _addToken(_tokenAddress, _isStablePool);
    }

    /**
     * @notice Menghapus token dari daftar yang didukung.
     */
    function removeSupportedToken(address _tokenAddress) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");

        isSupportedToken[_tokenAddress] = false;
        delete tokenUsesStablePool[_tokenAddress];

        for (uint i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == _tokenAddress) {
                supportedTokens[i] = supportedTokens[
                    supportedTokens.length - 1
                ];
                supportedTokens.pop();
                break;
            }
        }
        emit SupportedTokenRemoved(_tokenAddress);
    }

    /**
     * @notice Mengubah tipe pool (stable/volatile) untuk token yang sudah ada.
     */
    function updateTokenPoolType(
        address _tokenAddress,
        bool _isStablePool
    ) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");
        tokenUsesStablePool[_tokenAddress] = _isStablePool;
        emit TokenPoolTypeUpdated(_tokenAddress, _isStablePool);
    }

    /**
     * @notice Mengembalikan daftar lengkap token yang didukung.
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }
}

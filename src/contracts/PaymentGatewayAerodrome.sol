// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
}

// Struct PoolKey dari Aerodrome (untuk path)
struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
}

// Interface Aerodrome Router (kompatibel V2 tapi path IPoolKey[])
interface IAerodromeRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        PoolKey[] calldata pools, // Path sebagai array PoolKey (bukan address[])
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract PaymentGatewayAerodrome is Ownable {
    IERC20 public immutable idrxToken;
    IAerodromeRouter public immutable aerodromeRouter;

    mapping(address => bool) public isSupportedToken;
    mapping(address => uint24) public tokenFeeTier; // Fee tier per token (untuk PoolKey)

    address[] public supportedTokens;

    event PaymentProcessed(
        address indexed from,
        address indexed to,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOutIdrx,
        bool isSwapped
    );

    event SupportedTokenAdded(address indexed token, uint24 fee);
    event SupportedTokenRemoved(address indexed token);

    constructor(
        address _idrxAddress,
        address _routerAddress, // Aerodrome Router: 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43
        address[] memory _initialSupportedTokens,
        uint24[] memory _initialFees // Opsional, sama panjang dengan tokens
    ) Ownable(msg.sender) {
        require(_initialSupportedTokens.length == _initialFees.length, "Mismatched arrays");
        idrxToken = IERC20(_idrxAddress);
        aerodromeRouter = IAerodromeRouter(_routerAddress);

        for (uint i = 0; i < _initialSupportedTokens.length; i++) {
            address token = _initialSupportedTokens[i];
            uint24 fee = _initialFees[i];
            if (token != address(0) && !isSupportedToken[token]) {
                isSupportedToken[token] = true;
                tokenFeeTier[token] = fee;
                supportedTokens.push(token);
                emit SupportedTokenAdded(token, fee);
            }
        }
    }

    function transfer(
        address _tokenIn,
        address _to,
        uint256 _amountIn
    ) external {
        require(_to != address(0), "Transfer to the zero address");
        require(_amountIn > 0, "Transfer amount must be greater than zero");

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

    function _swapAndSend(
        IERC20 _tokenIn,
        address _recipient,
        uint256 _amountIn
    ) private {
        _tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        _tokenIn.approve(address(aerodromeRouter), _amountIn);

        // Buat PoolKey single-hop: tokenIn-IDRX dengan fee dari mapping
        PoolKey memory pool = PoolKey({
            currency0: _tokenIn < idrxToken ? address(_tokenIn) : address(idrxToken), // Sort token0 < token1
            currency1: _tokenIn < idrxToken ? address(idrxToken) : address(_tokenIn),
            fee: tokenFeeTier[address(_tokenIn)]
        });
        PoolKey[] memory pools = new PoolKey[](1);
        pools[0] = pool;

        uint[] memory amountsOut = aerodromeRouter.swapExactTokensForTokens(
            _amountIn,
            0, // amountOutMin=0 (ubah ke slippage protection kalau perlu)
            pools, // Path sebagai PoolKey[]
            _recipient,
            block.timestamp + 300 // Deadline 5 min
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

    function addSupportedToken(address _tokenAddress, uint24 _fee) external onlyOwner {
        require(_tokenAddress != address(0), "Cannot add zero address");
        require(_tokenAddress != address(idrxToken), "Cannot add IDRX token as swappable");
        require(!isSupportedToken[_tokenAddress], "Token already supported");
        require(_fee > 0, "Fee must be >0");

        isSupportedToken[_tokenAddress] = true;
        tokenFeeTier[_tokenAddress] = _fee;
        supportedTokens.push(_tokenAddress);
        emit SupportedTokenAdded(_tokenAddress, _fee);
    }

    function removeSupportedToken(address _tokenAddress) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");

        isSupportedToken[_tokenAddress] = false;
        delete tokenFeeTier[_tokenAddress];

        for (uint i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == _tokenAddress) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }
        emit SupportedTokenRemoved(_tokenAddress);
    }

    function setFeeTier(address _tokenAddress, uint24 _fee) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");
        require(_fee > 0, "Fee must be >0");
        tokenFeeTier[_tokenAddress] = _fee;
    }

    function getSupportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }
}
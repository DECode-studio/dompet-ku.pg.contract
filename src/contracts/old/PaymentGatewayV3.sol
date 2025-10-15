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

interface ISwapRouter {
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

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract PaymentGatewayV3 is Ownable {
    IERC20 public immutable idrxToken;
    ISwapRouter public immutable swapRouter;

    mapping(address => bool) public isSupportedToken;

    address[] public supportedTokens;

    // Fee tier untuk pair (default 3000 = 0.3%)
    mapping(address => uint24) public tokenFeeTier; // key: tokenIn

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
        address _routerAddress,
        address[] memory _initialSupportedTokens,
        uint24[] memory _initialFees // harus sama panjang dengan _initialSupportedTokens
    ) Ownable(msg.sender) {
        require(_initialSupportedTokens.length == _initialFees.length, "Mismatched arrays");
        idrxToken = IERC20(_idrxAddress);
        swapRouter = ISwapRouter(_routerAddress);

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

        _tokenIn.approve(address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(_tokenIn),
            tokenOut: address(idrxToken),
            fee: tokenFeeTier[address(_tokenIn)],
            recipient: _recipient,
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: 0, // Bisa diubah ke nilai slippage protection
            sqrtPriceLimitX96: 0
        });

        uint256 idrxReceived = swapRouter.exactInputSingle(params);

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
        require(
            _tokenAddress != address(idrxToken),
            "Cannot add IDRX token as swappable"
        );
        require(!isSupportedToken[_tokenAddress], "Token already supported");
        require(_fee > 0, "Fee must be greater than zero");

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
                supportedTokens[i] = supportedTokens[
                    supportedTokens.length - 1
                ];

                supportedTokens.pop();
                break;
            }
        }
        emit SupportedTokenRemoved(_tokenAddress);
    }

    function getSupportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }

    // Fungsi helper untuk set fee tier token existing (optional)
    function setFeeTier(address _tokenAddress, uint24 _fee) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");
        require(_fee > 0, "Fee must be greater than zero");
        tokenFeeTier[_tokenAddress] = _fee;
    }
}
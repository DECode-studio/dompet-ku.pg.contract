// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

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

interface IUniswapV2Router02 {
    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract PaymentGateway is Ownable {
    IERC20 public immutable idrxToken;
    IUniswapV2Router02 public immutable uniswapRouter;

    mapping(address => bool) public isSupportedToken;

    address[] public supportedTokens;

    event PaymentProcessed(
        address indexed from,
        address indexed to,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOutIdrx,
        bool isSwapped
    );

    event SupportedTokenAdded(address indexed token);
    event SupportedTokenRemoved(address indexed token);

    constructor(
        address _idrxAddress,
        address _routerAddress,
        address[] memory _initialSupportedTokens
    ) Ownable(msg.sender) {
        idrxToken = IERC20(_idrxAddress);
        uniswapRouter = IUniswapV2Router02(_routerAddress);

        for (uint i = 0; i < _initialSupportedTokens.length; i++) {
            address token = _initialSupportedTokens[i];
            if (token != address(0) && !isSupportedToken[token]) {
                isSupportedToken[token] = true;
                supportedTokens.push(token);
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

        _tokenIn.approve(address(uniswapRouter), _amountIn);

        address[] memory path = new address[](2);
        path[0] = address(_tokenIn);
        path[1] = address(idrxToken);

        uint[] memory amountsOut = uniswapRouter.swapExactTokensForTokens(
            _amountIn,
            0,
            path,
            _recipient,
            block.timestamp
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

    function addSupportedToken(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Cannot add zero address");
        require(
            _tokenAddress != address(idrxToken),
            "Cannot add IDRX token as swappable"
        );
        require(!isSupportedToken[_tokenAddress], "Token already supported");

        isSupportedToken[_tokenAddress] = true;
        supportedTokens.push(_tokenAddress);
        emit SupportedTokenAdded(_tokenAddress);
    }

    function removeSupportedToken(address _tokenAddress) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");

        isSupportedToken[_tokenAddress] = false;

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
}

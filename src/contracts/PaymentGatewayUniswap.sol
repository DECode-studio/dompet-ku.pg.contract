// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                            Interface TransferHelper                        */
/* -------------------------------------------------------------------------- */
interface ITransferHelper {
    function safeApprove(address token, address to, uint256 value) external;

    function safeTransfer(address token, address to, uint256 value) external;

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) external;
}

/**
 * Minimal versi helper (bisa digunakan langsung tanpa library eksternal)
 */
library TransferHelper {
    function safeApprove(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        ); // approve(address,uint256)
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Approve failed"
        );
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        ); // transfer(address,uint256)
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer failed"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        ); // transferFrom(address,address,uint256)
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferFrom failed"
        );
    }
}

/* -------------------------------------------------------------------------- */
/*                               ISwapRouter v3                               */
/* -------------------------------------------------------------------------- */
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

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

/* -------------------------------------------------------------------------- */
/*                        PaymentGatewayUniswapRouter.sol                     */
/* -------------------------------------------------------------------------- */
contract PaymentGatewayUniswapRouter is Ownable {
    ISwapRouter public immutable swapRouter;
    IERC20 public immutable idrxToken;

    mapping(address => bool) public isSupportedToken;
    address[] public supportedTokens;

    uint24 public constant FEE_TIER = 3000; // 0.05%

    event PaymentProcessed(
        address indexed from,
        address indexed to,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOutIdrx,
        bool isSwapped
    );

    constructor(
        address _idrxToken,
        address _uniswapRouter,
        address[] memory _initialSupportedTokens
    ) Ownable(msg.sender) {
        require(
            _idrxToken != address(0) && _uniswapRouter != address(0),
            "Zero address"
        );
        idrxToken = IERC20(_idrxToken);
        swapRouter = ISwapRouter(_uniswapRouter);

        for (uint256 i = 0; i < _initialSupportedTokens.length; i++) {
            _addToken(_initialSupportedTokens[i]);
        }
    }

    function transfer(
        address _tokenIn,
        address _to,
        uint256 _amountIn
    ) external {
        require(_to != address(0), "Zero to");
        require(_amountIn > 0, "Zero amount");

        if (_tokenIn == address(idrxToken)) {
            TransferHelper.safeTransferFrom(
                _tokenIn,
                msg.sender,
                _to,
                _amountIn
            );
            emit PaymentProcessed(
                msg.sender,
                _to,
                _tokenIn,
                _amountIn,
                _amountIn,
                false
            );
        } else if (isSupportedToken[_tokenIn]) {
            _swapViaUniswap(_tokenIn, _to, _amountIn);
        } else {
            revert("Token not supported");
        }
    }

    function _swapViaUniswap(
        address tokenIn,
        address to,
        uint256 amountIn
    ) internal {
        // 1️⃣ Tarik token dari user
        TransferHelper.safeTransferFrom(
            tokenIn,
            msg.sender,
            address(this),
            amountIn
        );

        // 2️⃣ Beri izin ke Uniswap router
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);

        // 3️⃣ Setup parameter swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: address(idrxToken),
                fee: FEE_TIER,
                recipient: to,
                deadline: block.timestamp + 300,
                amountIn: amountIn,
                amountOutMinimum: 0, // slippage bisa diatur di frontend
                sqrtPriceLimitX96: 0
            });

        // 4️⃣ Jalankan swap
        uint256 amountOut = swapRouter.exactInputSingle(params);

        emit PaymentProcessed(
            msg.sender,
            to,
            tokenIn,
            amountIn,
            amountOut,
            true
        );
    }

    /* --------------------------- Admin Functions --------------------------- */
    function _addToken(address _tokenAddress) private {
        require(
            _tokenAddress != address(0) && _tokenAddress != address(idrxToken),
            "Invalid token"
        );
        require(!isSupportedToken[_tokenAddress], "Already supported");

        isSupportedToken[_tokenAddress] = true;
        supportedTokens.push(_tokenAddress);
    }

    function addSupportedToken(address _tokenAddress) external onlyOwner {
        _addToken(_tokenAddress);
    }

    function removeSupportedToken(address _tokenAddress) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Not supported");
        isSupportedToken[_tokenAddress] = false;

        uint256 n = supportedTokens.length;
        for (uint256 i = 0; i < n; i++) {
            if (supportedTokens[i] == _tokenAddress) {
                supportedTokens[i] = supportedTokens[n - 1];
                supportedTokens.pop();
                break;
            }
        }
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// --------------------------------------------------------------------------
/// INTERFACES
/// --------------------------------------------------------------------------

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
}

interface IVelodromeRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function poolFor(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pool);
}

interface IVelodromeFactory {
    function getPool(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address);

    function isPool(address pool) external view returns (bool);
}

/**
 * @title PaymentGatewayVelodromeRouter
 * @notice Gateway pembayaran otomatis menggunakan Velodrome Finance (V2) di Lisk
 */
contract PaymentGatewayVelodromeRouter is Ownable {
    IERC20 public immutable idrxToken;
    IVelodromeRouter public immutable velodromeRouter;
    IVelodromeFactory public immutable velodromeFactory;

    /// Factory Velodrome di Lisk
    address public constant VELODROME_FACTORY =
        0x31832f2a97Fd20664D76Cc421207669b55CE4BC0;

    /// Common tokens
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDT = 0x05D032ac25d322df992303dCa074EE7392C117b9;

    mapping(address => bool) public isSupportedToken;
    mapping(address => bool) public tokenUsesStablePool;

    address[] public supportedTokens;

    /// EVENTS
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

    constructor(
        address _idrxToken,
        address _velodromeRouter,
        address[] memory _initialSupportedTokens,
        bool[] memory _initialIsStable
    ) Ownable(msg.sender) {
        require(
            _idrxToken != address(0) && _velodromeRouter != address(0),
            "Zero address"
        );
        require(
            _initialSupportedTokens.length == _initialIsStable.length,
            "Mismatched arrays"
        );

        idrxToken = IERC20(_idrxToken);
        velodromeRouter = IVelodromeRouter(_velodromeRouter);
        velodromeFactory = IVelodromeFactory(VELODROME_FACTORY);

        for (uint i = 0; i < _initialSupportedTokens.length; i++) {
            _addToken(_initialSupportedTokens[i], _initialIsStable[i]);
        }
    }

    function transfer(
        address _tokenIn,
        address _to,
        uint256 _amountIn
    ) external {
        require(_to != address(0), "Zero recipient");
        require(_amountIn > 0, "Zero amount");

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
            revert("Unsupported token");
        }
    }

    function routerPool(
        address a,
        address b,
        bool stable
    ) public view returns (address) {
        address predictedPool = velodromeRouter.poolFor(a, b, stable);
        return predictedPool;
    }

    function factoryPool(
        address a,
        address b,
        bool stable
    ) public view returns (address) {
        address predictedPool = velodromeFactory.getPool(a, b, stable);
        return predictedPool;
    }

    function hasPool(
        address a,
        address b,
        bool stable
    ) public view returns (bool) {
        address predictedPool = velodromeRouter.poolFor(a, b, stable);
        return velodromeFactory.isPool(predictedPool);
    }

    function _buildRoute(
        address tokenIn
    ) internal view returns (Route[] memory routes) {
        address tokenOut = address(idrxToken);

        if (hasPool(tokenIn, tokenOut, false)) {
            Route[] memory router = new Route[](1);
            router[0] = Route({from: tokenIn, to: tokenOut, stable: false});

            return router;
        }

        if (hasPool(tokenIn, WETH, false) && hasPool(WETH, tokenOut, false)) {
            Route[] memory router = new Route[](2);

            router[0] = Route({from: tokenIn, to: WETH, stable: false});
            router[1] = Route({from: WETH, to: tokenOut, stable: false});

            return router;
        }

        if (hasPool(tokenIn, USDT, false) && hasPool(USDT, tokenOut, false)) {
            Route[] memory router = new Route[](2);

            router[0] = Route({from: tokenIn, to: USDT, stable: false});
            router[1] = Route({from: USDT, to: tokenOut, stable: false});

            return router;
        }

        if (
            hasPool(tokenIn, USDT, false) &&
            hasPool(USDT, WETH, false) &&
            hasPool(WETH, tokenOut, false)
        ) {
            Route[] memory router = new Route[](3);

            router[0] = Route({from: tokenIn, to: USDT, stable: false});
            router[1] = Route({from: USDT, to: WETH, stable: false});
            router[2] = Route({from: WETH, to: tokenOut, stable: false});

            return router;
        }

        if (
            hasPool(tokenIn, WETH, false) &&
            hasPool(WETH, USDT, false) &&
            hasPool(WETH, tokenOut, false)
        ) {
            Route[] memory router = new Route[](3);

            router[0] = Route({from: tokenIn, to: USDT, stable: false});
            router[1] = Route({from: USDT, to: WETH, stable: false});
            router[2] = Route({from: WETH, to: tokenOut, stable: false});

            return router;
        }

        revert("No valid route found");
    }

    function _swapAndSend(
        IERC20 _tokenIn,
        address _recipient,
        uint256 _amountIn
    ) private {
        _tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        _tokenIn.approve(address(velodromeRouter), _amountIn);

        Route[] memory routes = _buildRoute(address(_tokenIn));

        uint256[] memory amountsOut = velodromeRouter.swapExactTokensForTokens(
            _amountIn,
            0,
            routes,
            _recipient,
            block.timestamp + 300
        );

        emit PaymentProcessed(
            msg.sender,
            _recipient,
            address(_tokenIn),
            _amountIn,
            amountsOut[amountsOut.length - 1],
            true
        );
    }

    function _addToken(address _token, bool _isStable) private {
        require(
            _token != address(0) && _token != address(idrxToken),
            "Invalid token"
        );
        require(!isSupportedToken[_token], "Already supported");

        isSupportedToken[_token] = true;
        tokenUsesStablePool[_token] = _isStable;
        supportedTokens.push(_token);

        emit SupportedTokenAdded(_token, _isStable);
    }

    function addSupportedToken(
        address _token,
        bool _isStable
    ) external onlyOwner {
        _addToken(_token, _isStable);
    }

    function removeSupportedToken(address _token) external onlyOwner {
        require(isSupportedToken[_token], "Not supported");
        isSupportedToken[_token] = false;
        delete tokenUsesStablePool[_token];

        for (uint i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == _token) {
                supportedTokens[i] = supportedTokens[
                    supportedTokens.length - 1
                ];
                supportedTokens.pop();
                break;
            }
        }

        emit SupportedTokenRemoved(_token);
    }

    function updateTokenPoolType(
        address _token,
        bool _isStable
    ) external onlyOwner {
        require(isSupportedToken[_token], "Not supported");
        tokenUsesStablePool[_token] = _isStable;
        emit TokenPoolTypeUpdated(_token, _isStable);
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }
}

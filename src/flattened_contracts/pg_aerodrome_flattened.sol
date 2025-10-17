// Sources flattened with hardhat v2.24.2 https://hardhat.org

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/utils/Context.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v5.3.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File src/contracts/PaymentGatewayAerodrome.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.20;

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

    function poolFor(
        address tokenA,
        address tokenB,
        bool stable,
        address factory
    ) external view returns (address);
}

interface IAerodromeFactory {
    function isPool(address pool) external view returns (bool);

    function getPool(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address);
}

/**
 * @title PaymentGatewayAerodromeRouter (flow ala Velodrome)
 * @notice Gateway pembayaran di Base dengan rute dinamis (direct / 2-hop / 3-hop)
 */
contract PaymentGatewayAerodromeRouter is Ownable {
    IERC20 public immutable idrxToken;
    IAerodromeRouter public immutable aerodromeRouter;
    IAerodromeFactory public immutable aerodromeFactory;

    address public constant AERODROME_FACTORY =
        0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

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
        aerodromeFactory = IAerodromeFactory(AERODROME_FACTORY);

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
            revert("Token not supported");
        }
    }

    function hasPool(
        address a,
        address b,
        bool stable
    ) public view returns (bool) {
        address predicted = aerodromeRouter.poolFor(
            a,
            b,
            stable,
            AERODROME_FACTORY
        );
        return aerodromeFactory.isPool(predicted);
    }

    function _buildRoute(
        address tokenIn
    ) internal view returns (Route[] memory routes) {
        address tokenOut = address(idrxToken);

        if (hasPool(tokenIn, tokenOut, tokenUsesStablePool[tokenIn])) {
            Route[] memory router = new Route[](1);
            router[0] = Route({
                from: tokenIn,
                to: tokenOut,
                stable: tokenUsesStablePool[tokenIn],
                factory: AERODROME_FACTORY
            });

            return router;
        }

        if (hasPool(tokenIn, WETH, false) && hasPool(WETH, tokenOut, false)) {
            Route[] memory router = new Route[](2);

            router[0] = Route({
                from: tokenIn,
                to: WETH,
                stable: false,
                factory: AERODROME_FACTORY
            });
            router[1] = Route({
                from: WETH,
                to: tokenOut,
                stable: false,
                factory: AERODROME_FACTORY
            });

            return router;
        }

        if (hasPool(tokenIn, USDC, false) && hasPool(USDC, tokenOut, false)) {
            Route[] memory router = new Route[](2);

            router[0] = Route({
                from: tokenIn,
                to: USDC,
                stable: false,
                factory: AERODROME_FACTORY
            });
            router[1] = Route({
                from: USDC,
                to: tokenOut,
                stable: false,
                factory: AERODROME_FACTORY
            });

            return router;
        }

        if (
            hasPool(tokenIn, USDC, false) &&
            hasPool(USDC, WETH, false) &&
            hasPool(WETH, tokenOut, false)
        ) {
            Route[] memory router = new Route[](3);

            router[0] = Route({
                from: tokenIn,
                to: USDC,
                stable: false,
                factory: AERODROME_FACTORY
            });
            router[1] = Route({
                from: USDC,
                to: WETH,
                stable: false,
                factory: AERODROME_FACTORY
            });
            router[2] = Route({
                from: WETH,
                to: tokenOut,
                stable: false,
                factory: AERODROME_FACTORY
            });

            return router;
        }

        if (
            hasPool(tokenIn, WETH, false) &&
            hasPool(WETH, USDC, false) &&
            hasPool(USDC, tokenOut, false)
        ) {
            Route[] memory router = new Route[](3);

            router[0] = Route({
                from: tokenIn,
                to: WETH,
                stable: false,
                factory: AERODROME_FACTORY
            });
            router[1] = Route({
                from: WETH,
                to: USDC,
                stable: false,
                factory: AERODROME_FACTORY
            });
            router[2] = Route({
                from: USDC,
                to: tokenOut,
                stable: false,
                factory: AERODROME_FACTORY
            });

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
        _tokenIn.approve(address(aerodromeRouter), _amountIn);

        Route[] memory routes = _buildRoute(address(_tokenIn));
        uint[] memory amountsOut = aerodromeRouter.swapExactTokensForTokens(
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

    function _addToken(address _tokenAddress, bool _isStablePool) private {
        require(
            _tokenAddress != address(0) && _tokenAddress != address(idrxToken),
            "Invalid token"
        );
        require(!isSupportedToken[_tokenAddress], "Already supported");

        isSupportedToken[_tokenAddress] = true;
        tokenUsesStablePool[_tokenAddress] = _isStablePool;
        supportedTokens.push(_tokenAddress);

        emit SupportedTokenAdded(_tokenAddress, _isStablePool);
    }

    function addSupportedToken(
        address _tokenAddress,
        bool _isStablePool
    ) external onlyOwner {
        _addToken(_tokenAddress, _isStablePool);
    }

    function removeSupportedToken(address _tokenAddress) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Not supported");
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

    function updateTokenPoolType(
        address _tokenAddress,
        bool _isStablePool
    ) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Not supported");
        tokenUsesStablePool[_tokenAddress] = _isStablePool;
        emit TokenPoolTypeUpdated(_tokenAddress, _isStablePool);
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }
}

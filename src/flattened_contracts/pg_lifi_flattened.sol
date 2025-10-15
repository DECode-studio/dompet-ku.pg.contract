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


// File src/contracts/PaymentGatewayLifi.sol

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

library LibSwap {
    struct SwapData {
        address callTo;
        address approveTo;
        address sendingAssetId;
        address receivingAssetId;
        uint256 fromAmount;
        bytes callData;
        bool requiresDeposit;
    }
}

interface ILiFiGenericSwap {
    function swapTokensGeneric(
        bytes32 _transactionId,
        string calldata _integrator,
        string calldata _referrer,
        address payable _receiver,
        uint256 _minAmount,
        LibSwap.SwapData[] calldata _swapData
    ) external payable;
}

/**
 * @title PaymentGatewayLiFiRouter
 * @notice Versi yang menggunakan struct TransferParams untuk menghindari "stack too deep"
 *         tapi tetap mempertahankan logika yang sama.
 */
contract PaymentGatewayLiFiRouter is Ownable {
    IERC20 public immutable idrxToken;
    address public constant LIFI_DIAMOND_BASE =
        0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;
    ILiFiGenericSwap public immutable lifi;

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
        address[] memory _initialSupportedTokens
    ) Ownable(msg.sender) {
        require(_idrxAddress != address(0), "Zero address");
        idrxToken = IERC20(_idrxAddress);
        lifi = ILiFiGenericSwap(LIFI_DIAMOND_BASE);

        for (uint256 i = 0; i < _initialSupportedTokens.length; i++) {
            _addToken(_initialSupportedTokens[i]);
        }
    }

    function transfer(
        address _tokenIn,
        address _to,
        uint256 _amountIn
    ) external {
        require(_to != address(0), "Transfer to zero");
        require(_amountIn > 0, "Zero amount");

        if (_tokenIn == address(idrxToken)) {
            require(
                IERC20(_tokenIn).transferFrom(msg.sender, _to, _amountIn),
                "transferFrom failed"
            );
            emit PaymentProcessed(
                msg.sender,
                _to,
                _tokenIn,
                _amountIn,
                _amountIn,
                false
            );
        } else {
            revert("Use transferViaLiFi for non-IDRX");
        }
    }

    /**
     * Struct untuk menggantikan parameter panjang di transferViaLiFi()
     */
    struct TransferParams {
        address tokenIn;
        address to;
        uint256 amountIn;
        bytes32 txId;
        uint256 minAmountOut;
        LibSwap.SwapData[] swapData;
        string integrator;
        string referrer;
    }

    /**
     * @notice Lakukan swap tokenIn -> IDRX menggunakan LiFi
     */
    function transferViaLiFi(TransferParams calldata p) external payable {
        require(p.to != address(0), "Transfer to zero");
        require(p.tokenIn != address(0), "Token zero");
        require(p.amountIn > 0, "Zero amount");
        require(p.tokenIn != address(idrxToken), "Use transfer for IDRX");
        require(isSupportedToken[p.tokenIn], "Token not supported");

        IERC20 token = IERC20(p.tokenIn);

        // 1. Tarik token dari pengguna
        require(
            token.transferFrom(msg.sender, address(this), p.amountIn),
            "transferFrom failed"
        );

        // 2. Beri izin ke LiFi router
        require(token.approve(LIFI_DIAMOND_BASE, p.amountIn), "approve failed");

        // 3. Jalankan swapTokensGeneric
        lifi.swapTokensGeneric{value: msg.value}(
            p.txId,
            p.integrator,
            p.referrer,
            payable(p.to),
            p.minAmountOut,
            p.swapData
        );

        emit PaymentProcessed(msg.sender, p.to, p.tokenIn, p.amountIn, 0, true);
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
        emit SupportedTokenAdded(_tokenAddress);
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
        emit SupportedTokenRemoved(_tokenAddress);
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }
}

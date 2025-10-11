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


// File src/contracts/PaymentGatewayAerodromeUniversal.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.20;

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

// Struct untuk V4Swap params (mirip manual trace)
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

// Interface UniversalRouter (dari code-mu)
interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

contract PaymentGatewayAerodromeUniversal is Ownable {
    IERC20 public immutable idrxToken;
    IUniversalRouter public immutable universalRouter;
    address public constant AERODROME_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da; // Factory
    bytes1 public constant V4_SWAP_EXACT_INPUT_SINGLE = 0x0a; // Command ID untuk V4 exactInputSingle

    mapping(address => bool) public isSupportedToken;
    mapping(address => uint24) public tokenFeeTier; // Fee tier per token
    mapping(address => bool) public tokenStablePool; // Stable/vol untuk pool

    address[] public supportedTokens;

    event PaymentProcessed(
        address indexed from,
        address indexed to,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOutIdrx,
        bool isSwapped
    );

    event SupportedTokenAdded(address indexed token, uint24 fee, bool stable);
    event SupportedTokenRemoved(address indexed token);

    constructor(
        address _idrxAddress,
        address _universalRouterAddress, // UniversalRouter: 0x01d40099fcd87c018969b0e8d4ab1633fb34763c
        address[] memory _initialSupportedTokens,
        uint24[] memory _initialFees,
        bool[] memory _initialStable // Sama panjang
    ) Ownable(msg.sender) {
        require(_initialSupportedTokens.length == _initialFees.length && _initialSupportedTokens.length == _initialStable.length, "Mismatched arrays");
        idrxToken = IERC20(_idrxAddress);
        universalRouter = IUniversalRouter(_universalRouterAddress);

        for (uint i = 0; i < _initialSupportedTokens.length; i++) {
            address token = _initialSupportedTokens[i];
            uint24 fee = _initialFees[i];
            bool stable = _initialStable[i];
            if (token != address(0) && !isSupportedToken[token]) {
                isSupportedToken[token] = true;
                tokenFeeTier[token] = fee;
                tokenStablePool[token] = stable;
                supportedTokens.push(token);
                emit SupportedTokenAdded(token, fee, stable);
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

        _tokenIn.approve(address(universalRouter), _amountIn);

        // Encode V4SwapRouter.exactInputSingle params (mirip manual trace)
        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: address(_tokenIn),
            tokenOut: address(idrxToken),
            fee: tokenFeeTier[address(_tokenIn)],
            recipient: _recipient,
            deadline: block.timestamp + 300,
            amountIn: _amountIn,
            amountOutMinimum: 0, // Ubah ke dynamic kalau perlu
            sqrtPriceLimitX96: 0
        });

        // Encode input bytes untuk command V4_SWAP_EXACT_INPUT_SINGLE (0x0a + params ABI)
        bytes memory input = abi.encode(params);

        // Commands: single byte array [V4_SWAP_EXACT_INPUT_SINGLE]
        bytes memory commands = abi.encodePacked(V4_SWAP_EXACT_INPUT_SINGLE);
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = input;

        // Call UniversalRouter.execute (dengan deadline)
        universalRouter.execute(commands, inputs, block.timestamp + 300);

        // Fetch idrxReceived dari event atau balance change (di sini assume dari transfer event, atau tambah query)
        uint256 idrxReceived = idrxToken.balanceOf(_recipient) - idrxToken.balanceOf(_recipient); // Adjust dengan before balance kalau perlu

        emit PaymentProcessed(
            msg.sender,
            _recipient,
            address(_tokenIn),
            _amountIn,
            idrxReceived,
            true
        );
    }

    function addSupportedToken(address _tokenAddress, uint24 _fee, bool _stable) external onlyOwner {
        require(_tokenAddress != address(0), "Cannot add zero address");
        require(_tokenAddress != address(idrxToken), "Cannot add IDRX token as swappable");
        require(!isSupportedToken[_tokenAddress], "Token already supported");
        require(_fee > 0, "Fee must be >0");

        isSupportedToken[_tokenAddress] = true;
        tokenFeeTier[_tokenAddress] = _fee;
        tokenStablePool[_tokenAddress] = _stable;
        supportedTokens.push(_tokenAddress);
        emit SupportedTokenAdded(_tokenAddress, _fee, _stable);
    }

    function removeSupportedToken(address _tokenAddress) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");

        isSupportedToken[_tokenAddress] = false;
        delete tokenFeeTier[_tokenAddress];
        delete tokenStablePool[_tokenAddress];

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

    function setStablePool(address _tokenAddress, bool _stable) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");
        tokenStablePool[_tokenAddress] = _stable;
    }

    function getSupportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }
}

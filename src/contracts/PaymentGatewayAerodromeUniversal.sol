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
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable;
}

contract PaymentGatewayAerodromeUniversal is Ownable {
    IERC20 public immutable idrxToken;
    IUniversalRouter public immutable universalRouter;
    address public constant AERODROME_FACTORY =
        0x420DD381b31aEf6683db6B902084cB0FFECe40Da; // Factory
    bytes1 public constant V3_SWAP_EXACT_IN = 0x00; // Command ID untuk V4 exactInputSingle

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
        require(
            _initialSupportedTokens.length == _initialFees.length &&
                _initialSupportedTokens.length == _initialStable.length,
            "Mismatched arrays"
        );
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
        // 1. Tarik token dari user ke contract ini
        _tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        // 2. Beri izin ke router untuk menarik token dari contract ini
        _tokenIn.approve(address(universalRouter), _amountIn);

        // 3. Catat saldo IDRX contract SEBELUM swap
        uint256 balanceBefore = idrxToken.balanceOf(address(this));

        // 4. Siapkan parameter untuk V3 swap
        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: address(_tokenIn),
            tokenOut: address(idrxToken),
            fee: tokenFeeTier[address(_tokenIn)], // Pastikan fee ini benar!
            recipient: address(this), // KIRIM HASIL SWAP KE CONTRACT INI DULU
            deadline: block.timestamp + 300,
            amountIn: _amountIn,
            amountOutMinimum: 0, // Set ke nilai yang wajar untuk proteksi slippage jika perlu
            sqrtPriceLimitX96: 0
        });

        // Encode input untuk command
        bytes memory input = abi.encode(params);

        // Siapkan commands dan inputs array
        bytes memory commands = abi.encodePacked(V3_SWAP_EXACT_IN); // GUNAKAN COMMAND V3
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = input;

        // 5. Panggil UniversalRouter.execute
        universalRouter.execute(commands, inputs, block.timestamp + 300);

        // 6. Hitung jumlah IDRX yang diterima
        uint256 balanceAfter = idrxToken.balanceOf(address(this));
        uint256 idrxReceived = balanceAfter - balanceBefore;

        require(idrxReceived > 0, "Swap resulted in no output");

        // 7. Kirim IDRX yang diterima ke penerima akhir
        idrxToken.transfer(_recipient, idrxReceived);

        emit PaymentProcessed(
            msg.sender,
            _recipient,
            address(_tokenIn),
            _amountIn,
            idrxReceived,
            true
        );
    }

    function addSupportedToken(
        address _tokenAddress,
        uint24 _fee,
        bool _stable
    ) external onlyOwner {
        require(_tokenAddress != address(0), "Cannot add zero address");
        require(
            _tokenAddress != address(idrxToken),
            "Cannot add IDRX token as swappable"
        );
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
                supportedTokens[i] = supportedTokens[
                    supportedTokens.length - 1
                ];
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

    function setStablePool(
        address _tokenAddress,
        bool _stable
    ) external onlyOwner {
        require(isSupportedToken[_tokenAddress], "Token not supported");
        tokenStablePool[_tokenAddress] = _stable;
    }

    function getSupportedTokensLength() external view returns (uint256) {
        return supportedTokens.length;
    }
}

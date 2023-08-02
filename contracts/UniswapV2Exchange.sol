// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract UniswapV2Exchange {
    address public immutable owner;
    address public immutable WETH;
    IUniswapV2Router02 public immutable uniswapRouter;

    bytes4 internal constant _ERC20_TRANSFER_ID = 0xa9059cbb;
    bytes4 internal constant _ERC20_TRANSFER_FROM_ID = 0x23b872dd;
    bytes4 internal constant _ERC20_APPROVE_ID = 0x095ea7b3;
    bytes4 internal constant _SWAP_EXACT_TOKENS_FOR_TOKENS = 0x38ed1739;
    bytes4 internal constant _SWAP_ETH_FOR_EXACT_TOKENS = 0xfb3bdb41;
    bytes4 internal constant _ERC20_BALANCE_ID = 0x70a08231;

    error NotOwner();
    error TransferFailed();
    error ApproveFailed();
    error SwapFailed();

    modifier onlyOwner() {
        address _owner = owner;

        assembly {
            if iszero(eq(caller(), _owner)) {
                let errorPtr := mload(0x40)
                mstore(errorPtr, 0x30cd747100000000000000000000000000000000000000000000000000000000)
                revert(errorPtr, 0x4)
            }
        }
        _;
    }

    constructor() {
        WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        owner = msg.sender;
    }

    receive() external payable {}

    function swapTokens(address _tokenToSell, address _tokenToBuy, uint256 _buyAmount) external {
        address _uniswapRouter = address(uniswapRouter);

        assembly {
            // transfer _tokenToSell
            mstore(0x7c, _ERC20_TRANSFER_FROM_ID)
            mstore(0x80, caller())
            mstore(0xa0, address())
            mstore(0xc0, _buyAmount)

            let s1 := call(gas(), _tokenToSell, 0, 0x7c, 0xc4, 0, 0)

            if iszero(s1) {
                let errorPtr := mload(0x40)
                mstore(errorPtr, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(errorPtr, 0x4)
            }

            // approve
            mstore(0x7c, _ERC20_APPROVE_ID)
            mstore(0x80, _uniswapRouter)
            mstore(0xa0, _buyAmount)

            let s2 := call(gas(), _tokenToSell, 0, 0x7c, 0xa4, 0, 0)

            if iszero(s2) {
                let errorPtr := mload(0x40)
                mstore(errorPtr, 0x3e3f8f7300000000000000000000000000000000000000000000000000000000)
                revert(errorPtr, 0x4)
            }

            // uniswapRouter.swapExactTokensForTokens
            mstore(0x7c, _SWAP_EXACT_TOKENS_FOR_TOKENS)
            mstore(0x80, _buyAmount)
            mstore(0xa0, 0)
            mstore(0xc0, 0xa0)
            mstore(0xe0, caller())
            mstore(0x100, timestamp())
            mstore(0x120, 0x02)
            mstore(0x140, _tokenToSell)
            mstore(0x160, _tokenToBuy)

            let s3 := call(gas(), _uniswapRouter, 0, 0x7c, 0x164, 0, 0)

            if iszero(s3) {
                let errorPtr := mload(0x40)
                mstore(errorPtr, 0x81ceff3000000000000000000000000000000000000000000000000000000000)
                revert(errorPtr, 0x4)
            }
        }
    }

    function swapTokensETH(address _tokenToBuy, uint256 _buyAmount) external payable {
        uint256 value = msg.value;
        address _uniswapRouter = address(uniswapRouter);
        address _WETH = WETH;

        assembly {
            // uniswapRouter.swapETHForExactTokens
            mstore(0x7c, _SWAP_ETH_FOR_EXACT_TOKENS)
            mstore(0x80, _buyAmount)
            mstore(0xa0, 0x80)
            mstore(0xc0, caller())
            mstore(0xe0, timestamp())
            mstore(0x100, 0x02)
            mstore(0x120, _WETH)
            mstore(0x140, _tokenToBuy)

            let success := call(gas(), _uniswapRouter, value, 0x7c, 0x144, 0, 0)

            if iszero(success) {
                let errorPtr := mload(0x40)
                mstore(errorPtr, 0x81ceff3000000000000000000000000000000000000000000000000000000000)
                revert(errorPtr, 0x4)
            }
        }
    }

    function withdrawTokens(address _token) external onlyOwner {
        assembly {
            // check balance
            mstore(0x7c, _ERC20_BALANCE_ID)
            mstore(0x80, address())

            let amount := call(gas(), _token, 0, 0x7c, 0x44, 0, 0)

            returndatacopy(0, 0, returndatasize())

            // transfer
            mstore(0x7c, _ERC20_TRANSFER_ID)
            mstore(0x80, caller())
            mstore(0xa0, mload(0))

            let success := call(gas(), _token, 0, 0x7c, 0x44, 0, 0)

            if iszero(success) {
                let errorPtr := mload(0x40)
                mstore(errorPtr, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(errorPtr, 0x4)
            }
        }
    }

    function withdrawETH() external onlyOwner {
        assembly {
            let amount := selfbalance()

            let success := call(gas(), caller(), amount, 0, 0, 0, 0)

            if iszero(success) {
                let errorPtr := mload(0x40)
                mstore(errorPtr, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(errorPtr, 0x4)
            }
        }
    }

    function getBalance() external view returns (uint256 bal) {
        assembly {
            bal := selfbalance()
        }
    }
}

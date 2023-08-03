// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract UniswapV2Exchange {
    address public immutable owner;
    address public immutable WETH;
    IUniswapV2Router02 public immutable uniswapRouter;

    bytes4 internal constant _ERC20_TRANSFER_ID = 0xa9059cbb;
    bytes4 internal constant _PAIR_SWAP_ID = 0x022c0d9f;
    bytes4 internal constant _ERC20_BALANCE_ID = 0x70a08231;

    error NotOwner();
    error TransferFailed();
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

    function swap(address _pair, address _tokenToBuy, uint256 _buyAmount) external {
        address token0 = IUniswapV2Pair(_pair).token0();
        address token1 = IUniswapV2Pair(_pair).token1();

        address _tokenToSell = token0 == _tokenToBuy ? token1 : token0;

        (uint256 reserveIn, uint256 reserveOut, ) = IUniswapV2Pair(_pair).getReserves();

        uint256 amountIn = uniswapRouter.getAmountIn(_buyAmount, reserveIn, reserveOut);

        assembly {
            // call transfer
            mstore(0x7c, _ERC20_TRANSFER_ID)
            mstore(0x80, _pair)
            mstore(0xa0, amountIn)

            let s1 := call(gas(), _tokenToSell, 0, 0x7c, 0x44, 0, 0)

            if iszero(s1) {
                let errorPtr := mload(0x40)
                mstore(errorPtr, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(errorPtr, 0x4)
            }

            // call swap
            mstore(0x7c, _PAIR_SWAP_ID)
            switch eq(token0, _tokenToBuy)
            case 0 {
                mstore(0x80, 0)
                mstore(0xa0, _buyAmount)
            }
            case 1 {
                mstore(0x80, _buyAmount)
                mstore(0xa0, 0)
            }
            mstore(0xc0, caller())
            mstore(0xe0, "")

            let s2 := call(gas(), _pair, 0, 0x7c, 0xa4, 0, 0)

            if iszero(s2) {
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
}

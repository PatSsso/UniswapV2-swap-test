// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract UniswapV2Exchange {
    address public immutable owner;

    bytes4 internal constant _ERC20_TRANSFER_ID = 0xa9059cbb;
    bytes4 internal constant _PAIR_SWAP_ID = 0x022c0d9f;
    bytes4 internal constant _ERC20_BALANCE_ID = 0x70a08231;
    bytes4 internal constant _GET_AMOUNT_IN = 0x85f8c259;

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
        owner = msg.sender;
    }

    function swap(address _pair, address _tokenToBuy, uint256 _buyAmount) external {
        // 130454
        address token0;
        address token1;
        address _tokenToSell;
        uint256 reserveIn;
        uint256 reserveOut;
        uint256 amountIn;

        assembly {
            mstore(0x00, 0x0dfe1681) // token0()
            let t0 := staticcall(gas(), _pair, 0x1c, 0x20, 0, 0)
            returndatacopy(0, 0, returndatasize())
            token0 := mload(0)

            mstore(0x00, 0xd21220a7) // token1()
            let t1 := staticcall(gas(), _pair, 0x1c, 0x20, 0, 0)
            returndatacopy(0, 0, returndatasize())
            token1 := mload(0)

            switch eq(token0, _tokenToBuy)
            case 0 {
                _tokenToSell := token0
            }
            case 1 {
                _tokenToSell := token1
            }

            mstore(0x00, 0x0902f1ac) // getReserves()
            let res := staticcall(gas(), _pair, 0x1c, 0x20, 0, 0)
            returndatacopy(0, 0, 64)
            reserveIn := mload(0)
            reserveOut := mload(32)

            // calculate amountIn
            mstore(0x7c, _GET_AMOUNT_IN)
            mstore(0x80, _buyAmount)
            switch eq(token0, _tokenToBuy)
            case 0 {
                mstore(0xa0, reserveIn)
                mstore(0xc0, reserveOut)
            }
            case 1 {
                mstore(0xa0, reserveOut)
                mstore(0xc0, reserveIn)
            }

            let a := staticcall(gas(), address(), 0x7c, 0xc4, 0, 0)

            returndatacopy(0, 0, returndatasize())
            amountIn := mload(0)

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

            let amount := staticcall(gas(), _token, 0x7c, 0x44, 0, 0)

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

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn) {
        assembly {
            let numerator := mul(reserveIn, amountOut)
            numerator := mul(numerator, 1000)

            let denominator := sub(reserveOut, amountOut)
            denominator := mul(denominator, 997)

            amountIn := add(div(numerator, denominator), 1)
        }
    }
}

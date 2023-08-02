import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { UniswapV2Exchange } from '../typechain';

import UniswapV2Router02 from '@uniswap/v2-periphery/build/IUniswapV2Router02.json';

const UNISWAP_V2_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
const BIG_1 = 10n ** 18n;

const amount = BIG_1;
const token0Amount = BIG_1;
const token1Amount = BIG_1;
const supply = 200n * BIG_1;
const buyAmount = 10n ** 15n;

const provider = ethers.provider;

async function getCurrentBlockTimestamp() {
  const blockNumber = await provider.getBlockNumber();
  const block = await provider.getBlock(blockNumber);
  const timestamp = block.timestamp;
  return timestamp;
}

describe('UniswapV2Router01 unit tests', function () {
  let exchange: UniswapV2Exchange;
  let token0: Contract;
  let token1: Contract;
  let owner: SignerWithAddress;
  let user: SignerWithAddress;
  let router: Contract;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    const EXCHANGE_FACTORY = await ethers.getContractFactory('UniswapV2Exchange');
    exchange = await EXCHANGE_FACTORY.deploy();

    const TOKENA_FACTORY = await ethers.getContractFactory('TokenA');
    token0 = await TOKENA_FACTORY.deploy();

    const TOKENB_FACTORY = await ethers.getContractFactory('TokenB');
    token1 = await TOKENB_FACTORY.deploy();

    router = new ethers.Contract(UNISWAP_V2_ROUTER, UniswapV2Router02.abi, owner);

    await token0.approve(router.address, supply);
    await token1.approve(router.address, supply);
  });

  it('#withdrawTokens', async function () {
    await token0.transfer(exchange.address, amount);

    expect(await token0.balanceOf(owner.address)).to.eq(supply - amount);
    expect(await token0.balanceOf(exchange.address)).to.eq(amount);

    const estimateGas = await exchange.estimateGas.withdrawTokens(token0.address);
    console.log('Tokens withdraw cost:', estimateGas.toString());

    await exchange.withdrawTokens(token0.address);

    expect(await token0.balanceOf(owner.address)).to.eq(supply);
    expect(await token0.balanceOf(exchange.address)).to.eq(0);
  });

  it('Should revert not owner if another user call withdraw function', async function () {
    await token0.transfer(exchange.address, amount);

    await expect(exchange.connect(user).withdrawTokens(token0.address)).to.be.revertedWithCustomError(
      exchange,
      'NotOwner'
    );
  });

  it('#swapTokens', async function () {
    await router.addLiquidity(
      token0.address,
      token1.address,
      token0Amount,
      token1Amount,
      0,
      0,
      owner.address,
      (await getCurrentBlockTimestamp()) + 10
    );

    const balance1Before = await token1.balanceOf(owner.address);

    expect(await token0.balanceOf(owner.address)).to.eq(supply - token0Amount);
    expect(await token0.balanceOf(exchange.address)).to.eq(0);

    await token0.approve(exchange.address, amount);

    const estimateGas = await exchange.estimateGas.swapTokens(token0.address, token1.address, buyAmount);
    console.log('Tokens swap cost:', estimateGas.toString());

    await exchange.swapTokens(token0.address, token1.address, buyAmount);

    const balance1After = await token1.balanceOf(owner.address);

    const amountOut = BigInt(balance1After) - BigInt(balance1Before);

    expect(await token0.balanceOf(owner.address)).to.eq(supply - buyAmount - token0Amount);
    expect(await token1.balanceOf(owner.address)).to.eq(supply + amountOut - token1Amount);
  });

  it('#swapETHToTokens', async function () {
    await router.addLiquidityETH(token0.address, token0Amount, 0, 0, owner.address, ethers.constants.MaxUint256, {
      value: amount,
    });

    expect(await token0.balanceOf(owner.address)).to.eq(supply - token0Amount);

    const estimateGas = await exchange.estimateGas.swapTokensETH(token0.address, buyAmount, { value: amount });
    console.log('Swap ETH for tokens cost:', estimateGas.toString());

    await exchange.swapTokensETH(token0.address, buyAmount, { value: amount });

    expect(await token0.balanceOf(owner.address)).to.eq(supply - token0Amount + buyAmount);

    // -----WITHDRAW-----
    expect(await exchange.getBalance()).greaterThan(0);

    const estimateGas_ = await exchange.estimateGas.withdrawETH();
    console.log('Withdraw ETH cost:', estimateGas_.toString());

    await exchange.withdrawETH();

    expect(await exchange.getBalance()).eq(0);
  });
});

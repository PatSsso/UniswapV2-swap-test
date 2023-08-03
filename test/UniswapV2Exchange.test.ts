import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { UniswapV2Exchange } from '../typechain';

import UniswapV2Router02 from '@uniswap/v2-periphery/build/IUniswapV2Router02.json';
import UniswapV2Factory from '@uniswap/v2-periphery/build/IUniswapV2Factory.json';

const UNISWAP_V2_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
const BIG_1 = 10n ** 18n;

const amount = BIG_1;
const token0Amount = 5n * BIG_1;
const token1Amount = 5n * BIG_1;
const supply = 200n * BIG_1;
const buyAmount = 2n * 10n ** 18n;

const provider = ethers.provider;

async function getCurrentBlockTimestamp() {
  const blockNumber = await provider.getBlockNumber();
  const block = await provider.getBlock(blockNumber);
  const timestamp = block.timestamp;
  return timestamp;
}

describe('Uniswap V2 exchange', function () {
  let exchange: UniswapV2Exchange;
  let token0: Contract;
  let token1: Contract;
  let owner: SignerWithAddress;
  let user: SignerWithAddress;
  let router: Contract;
  let factory: Contract;

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

    factory = new ethers.Contract(await router.factory(), UniswapV2Factory.abi, owner);

    await factory.createPair(token0.address, token1.address);
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

    const amountIn = await router.getAmountsIn(buyAmount, [token0.address, token1.address]);

    expect(await token0.balanceOf(owner.address)).to.eq(supply - token0Amount);
    expect(await token0.balanceOf(exchange.address)).to.eq(0);

    console.log(`Token balance before: ${(await token0.balanceOf(owner.address)) / 10 ** 18}`);
    console.log(`Token balance before: ${(await token1.balanceOf(owner.address)) / 10 ** 18}`);

    await token1.transfer(exchange.address, buyAmount * 3n);

    const pairAddress = await factory.getPair(token0.address, token1.address);

    const estimateGas = await exchange.estimateGas.swap(pairAddress, token0.address, buyAmount);
    console.log('Tokens swap cost:', estimateGas.toString());

    await exchange.swap(pairAddress, token0.address, buyAmount);

    console.log(`------BUY ${buyAmount / BIG_1} TOKENS------`);
    console.log(`Token balance after: ${(await token0.balanceOf(owner.address)) / 10 ** 18}`);
    console.log(`Token balance after: ${(await token1.balanceOf(owner.address)) / 10 ** 18}`);

    expect(await token0.balanceOf(owner.address)).to.eq(supply + buyAmount - token0Amount);
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
});

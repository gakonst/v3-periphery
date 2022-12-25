pragma solidity ^0.7.6;
pragma abicoder v2;

import './utils/Deploy.sol';
import './utils/Tick.sol';
import {encodePriceSqrt} from './utils/Math.sol';
import './utils/Path.sol';

import '../interfaces/INonfungiblePositionManager.sol';
import '../interfaces/ISwapRouter.sol';
import '../libraries/PoolAddress.sol';

import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

contract Swaps is SwapRouterFixture {
    function setUp() public override {
        super.setUp();

        createPool(address(tokens[0]), address(tokens[1]));
        createPool(address(tokens[1]), address(tokens[2]));
        createPoolWeth9(address(tokens[0]));
        createPoolWeth9(address(tokens[1]));
    }

    function createPool(address tokenAddressA, address tokenAddressB) public {
        if (tokenAddressA > tokenAddressB) {
            address tmp = tokenAddressA;
            tokenAddressA = tokenAddressB;
            tokenAddressB = tmp;
        }
        nft.createAndInitializePoolIfNecessary(tokenAddressA, tokenAddressB, FEE_MEDIUM, encodePriceSqrt(1, 1));

        INonfungiblePositionManager.MintParams memory liquidityParams =
            INonfungiblePositionManager.MintParams({
                token0: tokenAddressA,
                token1: tokenAddressB,
                fee: FEE_MEDIUM,
                tickLower: getMinTick(TICK_MEDIUM),
                tickUpper: getMaxTick(TICK_MEDIUM),
                recipient: wallet,
                amount0Desired: 1000000,
                amount1Desired: 1000000,
                amount0Min: 0,
                amount1Min: 0,
                deadline: 1
            });

        nft.mint(liquidityParams);
    }

    function createPoolWeth9(address tokenAddressA) public {
        uint256 liquidity = 1_000_000 * 1 ether;
        (bool success, bytes memory data) = address(weth9).call{value: liquidity}(abi.encodeWithSignature("deposit()"));
        weth9.approve(address(nft), type(uint256).max);
        return createPool(address(weth9), tokenAddressA);
    }
}

contract ExactInput is Swaps {
    function exactInput(
        address[] memory tokens,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) public {
        vm.startPrank(trader);

        bool inputIsWETH = tokens[0] == address(weth9);
        bool outputIsWETH = tokens[tokens.length - 1] == address(weth9);
        uint256 value = inputIsWETH ? amountIn : 0;

        uint24[] memory fees = new uint24[](tokens.length - 1);
        for (uint256 i = 0; i < fees.length; i++) {
            fees[i] = FEE_MEDIUM;
        }

        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({
                path: encodePath(tokens, fees),
                recipient: outputIsWETH ? address(0) : trader,
                deadline: 1,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum
            });

        bytes[] memory data;
        bytes memory inputs = abi.encodeWithSelector(router.exactInput.selector, params);
        if (outputIsWETH) {
            data = new bytes[](2);
            data[0] = inputs;
            data[1] = abi.encodeWithSelector(router.unwrapWETH9.selector, amountOutMinimum, trader);
        }

        // ensure that the swap fails if the limit is any higher
        params.amountOutMinimum += 1;
        vm.expectRevert(bytes('Too little received'));
        router.exactInput{value: value}(params);
        params.amountOutMinimum -= 1;

        if (outputIsWETH) {
            router.multicall{value: value}(data);
        } else {
            router.exactInput{value: value}(params);
        }

        vm.stopPrank();
    }
}

contract SinglePool is ExactInput {
    function testZeroToOne() public {
        address pool = factory.getPool(address(tokens[0]), address(tokens[1]), FEE_MEDIUM);

        Balances memory poolBefore = getBalances(pool);
        Balances memory traderBefore = getBalances(trader);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(tokens[0]);
        _tokens[1] = address(tokens[1]);
        exactInput(_tokens, 3, 1);

        Balances memory poolAfter = getBalances(pool);
        Balances memory traderAfter = getBalances(trader);
        require(traderAfter.token0 == traderBefore.token0 - 3);
        require(traderAfter.token1 == traderBefore.token1 + 1);
        require(poolAfter.token0 == poolBefore.token0 + 3);
        require(poolAfter.token1 == poolBefore.token1 - 1);
    }

    function testOneToZero() public {
        address pool = factory.getPool(address(tokens[1]), address(tokens[0]), FEE_MEDIUM);

        Balances memory poolBefore = getBalances(pool);
        Balances memory traderBefore = getBalances(trader);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(tokens[1]);
        _tokens[1] = address(tokens[0]);
        exactInput(_tokens, 3, 1);

        Balances memory poolAfter = getBalances(pool);
        Balances memory traderAfter = getBalances(trader);
        require(traderAfter.token0 == traderBefore.token0 + 1);
        require(traderAfter.token1 == traderBefore.token1 - 3);
        require(poolAfter.token0 == poolBefore.token0 - 1);
        require(poolAfter.token1 == poolBefore.token1 + 3);
    }
}

contract MultiPool is ExactInput {
    function testZeroToOneToTwo() public {
        Balances memory traderBefore = getBalances(trader);

        address[] memory _tokens = new address[](3);
        _tokens[0] = address(tokens[0]);
        _tokens[1] = address(tokens[1]);
        _tokens[2] = address(tokens[2]);
        exactInput(_tokens, 5, 1);

        Balances memory traderAfter = getBalances(trader);
        require(traderAfter.token0 == traderBefore.token0 - 5);
        require(traderAfter.token2 == traderBefore.token2 + 1);
    }

    function testTwoToOneToZero() public {
        Balances memory traderBefore = getBalances(trader);

        address[] memory _tokens = new address[](3);
        _tokens[0] = address(tokens[2]);
        _tokens[1] = address(tokens[1]);
        _tokens[2] = address(tokens[0]);
        exactInput(_tokens, 5, 1);

        Balances memory traderAfter = getBalances(trader);
        require(traderAfter.token2 == traderBefore.token2 - 5);
        require(traderAfter.token0 == traderBefore.token0 + 1);
    }

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function testEvents() public {
        address[] memory _tokens = new address[](3);
        _tokens[0] = address(tokens[0]);
        _tokens[1] = address(tokens[1]);
        _tokens[2] = address(tokens[2]);

        PoolAddress.PoolKey memory key;
        address addr;

        // Events get emitted in the following order:
        // 1. Pool0 -> Router
        // 2. Trader -> Pool0
        // 3. Pool1 -> Trader
        // 4. Router -> Pool1

        vm.expectEmit(true, true, true, true);
        key = PoolAddress.PoolKey(address(tokens[1]), address(tokens[0]), FEE_MEDIUM);
        addr = PoolAddress.computeAddress(address(factory), key);
        emit Transfer(addr, address(router), 3);

        vm.expectEmit(true, true, true, true);
        key = PoolAddress.PoolKey(address(tokens[1]), address(tokens[0]), FEE_MEDIUM);
        addr = PoolAddress.computeAddress(address(factory), key);
        emit Transfer(trader, addr, 5);

        vm.expectEmit(true, true, true, true);
        key = PoolAddress.PoolKey(address(tokens[1]), address(tokens[2]), FEE_MEDIUM);
        addr = PoolAddress.computeAddress(address(factory), key);
        emit Transfer(addr, trader, 1);

        vm.expectEmit(true, true, true, true);
        key = PoolAddress.PoolKey(address(tokens[1]), address(tokens[2]), FEE_MEDIUM);
        addr = PoolAddress.computeAddress(address(factory), key);
        emit Transfer(address(router), addr, 3);

        exactInput(_tokens, 5, 1);
    }
}

contract EthInput is ExactInput {
    function testWeth9ToZero() public {
        address pool = factory.getPool(address(weth9), address(tokens[0]), FEE_MEDIUM);

        Balances memory poolBefore = getBalances(pool);
        Balances memory traderBefore = getBalances(trader);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(weth9);
        _tokens[1] = address(tokens[0]);
        exactInput(_tokens, 3, 1);

        Balances memory poolAfter = getBalances(pool);
        Balances memory traderAfter = getBalances(trader);

        require(traderAfter.token0 == traderBefore.token0 + 1);
        require(poolAfter.weth9 == poolBefore.weth9 + 3);
        require(poolAfter.token0 == poolBefore.token0 - 1);
    }

    function testWeth9ToZeroToOne() public {
        Balances memory traderBefore = getBalances(trader);

        address[] memory _tokens = new address[](3);
        _tokens[0] = address(weth9);
        _tokens[1] = address(tokens[0]);
        _tokens[2] = address(tokens[1]);
        exactInput(_tokens, 5, 1);

        Balances memory traderAfter = getBalances(trader);
        require(traderAfter.token1 == traderBefore.token1 + 1);
    }
}

contract EthOutput is ExactInput {
    function testZeroToWeth9() public {
        address pool = factory.getPool(address(tokens[0]), address(weth9), FEE_MEDIUM);

        Balances memory poolBefore = getBalances(pool);
        Balances memory traderBefore = getBalances(trader);

        address[] memory _tokens = new address[](2);
        _tokens[0] = address(tokens[0]);
        _tokens[1] = address(weth9);
        exactInput(_tokens, 3, 1);

        Balances memory poolAfter = getBalances(pool);
        Balances memory traderAfter = getBalances(trader);

        require(traderAfter.token0 == traderBefore.token0 - 3);
        require(poolAfter.weth9 == poolBefore.weth9 - 1);
        require(poolAfter.token0 == poolBefore.token0 + 3);
    }

    function testZeroToOneToWeth9() public {
        Balances memory traderBefore = getBalances(trader);

        address[] memory _tokens = new address[](3);
        _tokens[0] = address(tokens[0]);
        _tokens[1] = address(tokens[1]);
        _tokens[2] = address(weth9);
        exactInput(_tokens, 5, 1);

        Balances memory traderAfter = getBalances(trader);
        require(traderAfter.token0 == traderBefore.token0 - 5);
    }
}
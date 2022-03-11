pragma solidity ^0.7.6;
pragma abicoder v2;

import "./utils/Deploy.sol";
import "./utils/Tick.sol";
import { encodePriceSqrt } from "./utils/Math.sol";

import "../interfaces/INonfungiblePositionManager.sol";

contract Swaps is SwapRouterFixture {
	function setUp() public override {
		super.setUp();

		createPool(address(tokens[0]), address(tokens[1]));
		createPool(address(tokens[1]), address(tokens[2]));
	}

	function createPool(address tokenAddressA, address tokenAddressB) public {
		if (tokenAddressA > tokenAddressB) {
			address tmp = tokenAddressA;
			tokenAddressA = tokenAddressB;
			tokenAddressB = tmp;
		}
		nft.createAndInitializePoolIfNecessary(
			tokenAddressA,
			tokenAddressB,
			FEE_MEDIUM,
			encodePriceSqrt(1, 1)
		);

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
}

pragma solidity ^0.7.6;

// test helpers for converting prices
import { encodePriceSqrt } from "./utils/Math.sol";

import "contracts/libraries/LiquidityAmounts.sol";

contract GetLiquidityForAmounts {
    function testAmountsForPriceInside() public pure {
        uint160 sqrtPriceX96 = encodePriceSqrt(1, 1);
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            100,
            200
        );
        require(liquidity == 2148);
    }
}

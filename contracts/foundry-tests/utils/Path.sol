pragma solidity ^0.7.6;

import '../../libraries/Path.sol';
import {FEE_HIGH, FEE_MEDIUM} from './Tick.sol';

function encodePath(address[] memory path, uint24[] memory fees) returns (bytes memory) {
    bytes memory res;
    for (uint256 i = 0; i < fees.length; i++) {
        res = abi.encodePacked(res, path[i], fees[i]);
    }
    res = abi.encodePacked(res, path[path.length - 1]);
    return res;
}

// Foundry allows defining tests in the same file as the one where your code is.
// In an ideal world, we'd also have something like `#[cfg(test)]` which prevents
// the code from being compiled when building outside of tests.
contract PathsTest {
    function testRoundtrip() public {
        address[] memory tokens = new address[](3);
        tokens[0] = address(uint256(keccak256('0x1234')));
        tokens[1] = address(uint256(keccak256('0x123456')));
        tokens[2] = address(uint256(keccak256('0x12345678')));
        uint24[] memory fees = new uint24[](2);
        fees[0] = FEE_MEDIUM;
        fees[1] = FEE_HIGH;
        bytes memory path = encodePath(tokens, fees);

        require(Path.numPools(path) == 2, 'unequal path len');
        (address token0, address token1, uint24 fee) = Path.decodeFirstPool(path);
        require(token0 == tokens[0]);
        require(token1 == tokens[1]);
        require(fee == FEE_MEDIUM);

        path = Path.skipToken(path);
        (token0, token1, fee) = Path.decodeFirstPool(path);
        require(token0 == tokens[1]);
        require(token1 == tokens[2]);
        require(fee == FEE_HIGH);
    }
}

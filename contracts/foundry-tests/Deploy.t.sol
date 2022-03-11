pragma solidity ^0.7.6;

import "./utils/Test.sol";

import "contracts/SwapRouter.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant v3FactoryArtifact = "node_modules/@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json";
string constant weth9Artifact = "test/contracts/WETH9.json";

interface WETH9 is IERC20Minimal {
    function deposit() payable external;
}

// Base fixture deploying V3 Factory, V3 Router and WETH9
contract V3RouterFixture is Test {
    IUniswapV3Factory public factory;
    WETH9 public weth9;
    SwapRouter public router;

    // Deploys WETH9 and V3 Core's Factory contract, and then
    // hooks them on the router
    function setUp() virtual public {
        address _weth9 = deployCode(weth9Artifact);
        weth9 = WETH9(_weth9);

        address _factory = deployCode(v3FactoryArtifact);
        factory = IUniswapV3Factory(_factory);

        router = new SwapRouter(_factory, _weth9);
    }
}

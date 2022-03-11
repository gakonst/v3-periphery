pragma solidity ^0.7.6;

import "./utils/Test.sol";

import "contracts/test/TestERC20.sol";

import "contracts/SwapRouter.sol";
import "contracts/NonfungibleTokenPositionDescriptor.sol";
import "contracts/NonfungiblePositionManager.sol";

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

// Fixture which deploys the 3 tokens we'll use in the tests and the NFT position manager
contract CompleteFixture is V3RouterFixture {
    TestERC20[] tokens;
    NonfungibleTokenPositionDescriptor nftDescriptor;
    NonfungiblePositionManager nft;

    function setUp() virtual override public {
        super.setUp();

        // deploy the 3 tokens
        address token0 = address(new TestERC20(type(uint256).max / 2));
        address token1 = address(new TestERC20(type(uint256).max / 2));
        address token2 = address(new TestERC20(type(uint256).max / 2));
        require(token0 < token1, "unexpected token ordering 1");
        require(token2 < token1, "unexpected token ordering 2");
        // pre-sorted manually, TODO do this properly
        tokens.push(TestERC20(token1));
        tokens.push(TestERC20(token2));
        tokens.push(TestERC20(token0));

        // we don't need to do the lib linking, forge deploys
        // all libraries and does it for us
        nftDescriptor = new NonfungibleTokenPositionDescriptor(
            address(tokens[0]),
            bytes32("ETH")
        );

        nft = new NonfungiblePositionManager(address(factory), address(weth9), address(nftDescriptor));
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "../contracts/test/TestTokenA.sol";
import "../contracts/test/TestTokenB.sol";
import "../contracts/test/TestTokenC.sol";
import "../contracts/Router.sol";
import "../contracts/interfaces/factories/IPoolFactory.sol";
import "../contracts/interfaces/IPool.sol";
import "../contracts/interfaces/factories/IFactoryRegistry.sol";

contract SetupSwap is Script {
    using stdJson for string;

    address public deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // First anvil account

    TestTokenA public tokenA;
    TestTokenB public tokenB;
    TestTokenC public tokenC;
    Router public router;
    IPoolFactory public poolFactory;
    IPool public poolAB;
    IPool public poolAC;
    IPool public poolCB;
    IFactoryRegistry public factoryRegistry;

    uint256 public constant INITIAL_LIQUIDITY_A = 100000 * 1e18; // 100k tokens
    uint256 public constant INITIAL_LIQUIDITY_B = 100000 * 1e18; // 100k tokens
    uint256 public constant INITIAL_LIQUIDITY_C = 100000 * 1e18; // 100k tokens

    function run() public {
        vm.startBroadcast(deployer);

        // Load existing contracts from deployment
        string memory deploymentFile = "anvil_deployment.json";
        string memory json = vm.readFile(deploymentFile);
        router = Router(payable(abi.decode(vm.parseJson(json, ".router"), (address))));

        factoryRegistry = IFactoryRegistry(router.factoryRegistry());
        poolFactory = IPoolFactory(router.defaultFactory());

        console.log("Using Router at:", address(router));
        console.log("Using PoolFactory at:", address(poolFactory));

        // Deploy test tokens
        tokenA = new TestTokenA();
        tokenB = new TestTokenB();
        tokenC = new TestTokenC();

        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));
        console.log("TokenC deployed at:", address(tokenC));

        // Create pools for multi-route setup
        poolAB = IPool(poolFactory.createPool(address(tokenA), address(tokenB), false)); // volatile pool
        poolAC = IPool(poolFactory.createPool(address(tokenA), address(tokenC), false)); // volatile pool
        poolCB = IPool(poolFactory.createPool(address(tokenC), address(tokenB), false)); // volatile pool

        console.log("Pool A-B created at:", address(poolAB));
        console.log("Pool A-C created at:", address(poolAC));
        console.log("Pool C-B created at:", address(poolCB));

        // Check and approve router to spend tokens if needed
        uint256 allowanceA = tokenA.allowance(deployer, address(router));
        if (allowanceA < INITIAL_LIQUIDITY_A * 2) { // Need more tokens for multiple pools
            console.log("Approving TokenA for Router...");
            tokenA.approve(address(router), type(uint256).max);
        } else {
            console.log("TokenA already approved for Router");
        }

        uint256 allowanceB = tokenB.allowance(deployer, address(router));
        if (allowanceB < INITIAL_LIQUIDITY_B * 2) { // Need more tokens for multiple pools
            console.log("Approving TokenB for Router...");
            tokenB.approve(address(router), type(uint256).max);
        } else {
            console.log("TokenB already approved for Router");
        }

        uint256 allowanceC = tokenC.allowance(deployer, address(router));
        if (allowanceC < INITIAL_LIQUIDITY_C * 2) { // Need tokens for both A-C and C-B pools
            console.log("Approving TokenC for Router...");
            tokenC.approve(address(router), type(uint256).max);
        } else {
            console.log("TokenC already approved for Router");
        }

        // Add initial liquidity to A-B pool
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            false, // volatile
            INITIAL_LIQUIDITY_A,
            INITIAL_LIQUIDITY_B,
            INITIAL_LIQUIDITY_A * 95 / 100, // 5% slippage
            INITIAL_LIQUIDITY_B * 95 / 100,
            deployer,
            block.timestamp + 1 hours
        );

        // Add initial liquidity to A-C pool
        router.addLiquidity(
            address(tokenA),
            address(tokenC),
            false, // volatile
            INITIAL_LIQUIDITY_A,
            INITIAL_LIQUIDITY_C,
            INITIAL_LIQUIDITY_A * 95 / 100, // 5% slippage
            INITIAL_LIQUIDITY_C * 95 / 100,
            deployer,
            block.timestamp + 1 hours
        );

        // Add initial liquidity to C-B pool
        router.addLiquidity(
            address(tokenC),
            address(tokenB),
            false, // volatile
            INITIAL_LIQUIDITY_C,
            INITIAL_LIQUIDITY_B,
            INITIAL_LIQUIDITY_C * 95 / 100, // 5% slippage
            INITIAL_LIQUIDITY_B * 95 / 100,
            deployer,
            block.timestamp + 1 hours
        );

        console.log("Liquidity added successfully to all pools");
        console.log("Pool A-B balance A:", tokenA.balanceOf(address(poolAB)));
        console.log("Pool A-B balance B:", tokenB.balanceOf(address(poolAB)));
        console.log("Pool A-C balance A:", tokenA.balanceOf(address(poolAC)));
        console.log("Pool A-C balance C:", tokenC.balanceOf(address(poolAC)));
        console.log("Pool C-B balance C:", tokenC.balanceOf(address(poolCB)));
        console.log("Pool C-B balance B:", tokenB.balanceOf(address(poolCB)));

        // Mint additional tokens for swapping
        tokenA.mint(deployer, 50000 * 1e18);
        tokenB.mint(deployer, 50000 * 1e18);
        tokenC.mint(deployer, 50000 * 1e18);

        vm.stopBroadcast();

        // Save swap setup info
        string memory swapInfo = string.concat(
            '{\n',
            '  "tokenA": "', vm.toString(address(tokenA)), '",\n',
            '  "tokenB": "', vm.toString(address(tokenB)), '",\n',
            '  "tokenC": "', vm.toString(address(tokenC)), '",\n',
            '  "poolAB": "', vm.toString(address(poolAB)), '",\n',
            '  "poolAC": "', vm.toString(address(poolAC)), '",\n',
            '  "poolCB": "', vm.toString(address(poolCB)), '",\n',
            '  "router": "', vm.toString(address(router)), '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "multi_route_setup": true,\n',
            '  "setup_complete": true\n',
            '}'
        );

        vm.writeFile("anvil_swap_setup.json", swapInfo);
        console.log("Multi-route swap setup complete! Info saved to anvil_swap_setup.json");
    }
}
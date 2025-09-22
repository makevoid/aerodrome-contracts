// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "../contracts/test/TestTokenA.sol";
import "../contracts/test/TestTokenB.sol";
import "../contracts/Router.sol";
import "../contracts/interfaces/IRouter.sol";
import "../contracts/interfaces/IPool.sol";

contract ExecuteSwap is Script {
    using stdJson for string;

    address public deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public constant SWAP_AMOUNT = 1e18; // 1 token

    function run() public {
        // Load swap setup
        string memory setupFile = "anvil_swap_setup.json";
        string memory json = vm.readFile(setupFile);

        address tokenAAddr = abi.decode(vm.parseJson(json, ".tokenA"), (address));
        address tokenBAddr = abi.decode(vm.parseJson(json, ".tokenB"), (address));
        address routerAddr = abi.decode(vm.parseJson(json, ".router"), (address));
        address poolAddr = abi.decode(vm.parseJson(json, ".pool"), (address));

        TestTokenA tokenA = TestTokenA(tokenAAddr);
        TestTokenB tokenB = TestTokenB(tokenBAddr);
        Router router = Router(payable(routerAddr));
        IPool pool = IPool(poolAddr);

        vm.startBroadcast(deployer);

        console.log("=== BEFORE SWAP ===");
        uint256 balanceABefore = tokenA.balanceOf(deployer);
        uint256 balanceBBefore = tokenB.balanceOf(deployer);
        console.log("TokenA balance:", balanceABefore);
        console.log("TokenB balance:", balanceBBefore);

        // Check pool reserves
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        console.log("Pool reserves - Token0:", reserve0, "Token1:", reserve1);

        // Check and approve if needed
        uint256 allowanceA = tokenA.allowance(deployer, address(router));
        if (allowanceA < SWAP_AMOUNT) {
            console.log("Approving TokenA for swap...");
            tokenA.approve(address(router), type(uint256).max);
        } else {
            console.log("TokenA already approved");
        }

        // Create swap routes
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: address(tokenA),
            to: address(tokenB),
            stable: false, // volatile pool
            factory: router.defaultFactory()
        });

        // Calculate minimum output (with 1% slippage)
        uint256[] memory amountsOut = router.getAmountsOut(SWAP_AMOUNT, routes);
        uint256 minAmountOut = amountsOut[1] * 99 / 100; // 1% slippage

        console.log("Swapping TokenA for TokenB");
        console.log("Amount in:", SWAP_AMOUNT);
        console.log("Min amount out:", minAmountOut);

        // Execute swap
        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            minAmountOut,
            routes,
            deployer,
            block.timestamp + 1 hours
        );

        console.log("=== AFTER SWAP ===");
        uint256 balanceAAfter = tokenA.balanceOf(deployer);
        uint256 balanceBAfter = tokenB.balanceOf(deployer);
        console.log("TokenA balance:", balanceAAfter);
        console.log("TokenB balance:", balanceBAfter);

        console.log("=== SWAP RESULTS ===");
        console.log("TokenA spent:", balanceABefore - balanceAAfter);
        console.log("TokenB received:", balanceBAfter - balanceBBefore);

        // Check new pool reserves
        (reserve0, reserve1,) = pool.getReserves();
        console.log("New pool reserves - Token0:", reserve0, "Token1:", reserve1);

        vm.stopBroadcast();

        console.log("Swap completed successfully!");
    }
}
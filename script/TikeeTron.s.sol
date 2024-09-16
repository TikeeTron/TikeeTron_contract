// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/TikeeTron.sol";

contract TikeeTronScript is Script {
    function setUp() public {
        vm.startBroadcast();
        new TikeeTron();
        vm.stopBroadcast();
    }
}

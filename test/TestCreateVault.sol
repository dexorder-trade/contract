
pragma solidity 0.8.28;

import "@forge-std/console2.sol";
import "../src/core/VaultFactory.sol";
import "../src/more/VaultAddress.sol";
import "@forge-std/Test.sol";
import {MockEnv} from "./MockEnv.sol";

contract TestCreateVault is Test, MockEnv {

    Vault public vault;

    function setUp() public {
        initNoFees();
        console2.log('factory');
        console2.log(address(factory));
    }

    function testCreateVault() public {
        factory.deployVault(address(this));
    }

}

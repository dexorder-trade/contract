
pragma solidity 0.8.28;

import "@forge-std/console2.sol";
import "../src/core/VaultFactory.sol";
import "../src/more/VaultAddress.sol";
import "@forge-std/Test.sol";
import "../src/interface/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockEnv} from "./MockEnv.sol";

contract TestCoin is ERC20 {
    constructor(uint256 initialSupply) ERC20("TestCoin", "TCOIN") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TestDeployVault is Test, MockEnv {
    function setUp() public {
        initNoFees();
    }

    function testDeployVault() public {
        factory.deployVault();
    }
}

contract TestVault is Test, MockEnv {

    IVault public vault;
    address payable owner = payable(address(this)); // this contract owns vault

    receive() external payable {} // this is owner and needs to be able to receive native

    uint256 constant runnerGib = 2**96-1; // Test runner gives Test{} some native to start;

    function setUp() public {
        initNoFees();
        console2.log("setUp()");
        console2.log("msg.sender, balance  ", msg.sender, payable(msg.sender).balance);
        console2.log("owner, balance       ", owner, owner.balance);
        assert (owner == address(this));
        assert (owner.balance == runnerGib);

        console2.log("factory, balance     ", address(factory), address(factory).balance);

        vault = factory.deployVault(owner);
        assert (vault.owner() == owner);
        console2.log("vault, balance       ", address(vault), address(vault).balance);
    }

    function testDeterministicAddress() public view {
        console2.log(address(vault));
        address d = VaultAddress.computeAddress(address(factory), owner);
        console2.log(d);
        assert(address(vault) == d);
    }

    function testWithdraw() public {

        console2.log("testWithdraw()");
        console2.log("msg.sender, balance  ", msg.sender, msg.sender.balance); // msg.sender == test runner

        // get vault address and give some eth
        address payable vaultAddr = payable(address(vault));
        assert(vaultAddr.balance == 0);
        uint256 vaultNative = 1 ether;
        vm.deal(vaultAddr, vaultNative); // Give vault some native
        console2.log("vault, balance       ", address(vault), address(vault).balance);
        assert (vaultAddr.balance == vaultNative);

        // get address for withdrawTo()
        uint256 seed = uint256(keccak256(abi.encodePacked("testSeed")));
        address payable toAddr = payable(vm.addr(seed));

        // Verify native withdrawTo()
        assert(vaultAddr.balance == vaultNative);
        assert(toAddr.balance == 0);
        vault.withdrawTo(toAddr, 100);
        assert(toAddr.balance == 100);
        assert(vaultAddr.balance == vaultNative - 100);

        // Verify native withdraw()
        vault.withdraw(100);
        assert(vaultAddr.balance == vaultNative - 200);
        assert(owner.balance == runnerGib + 100);
        console2.log("owner, balance       ", owner, owner.balance);

    }

    function testWithdrawERC20() public {

        TestCoin testCoin = new TestCoin(0); // Zero tokens to start

        console2.log("testWithdrawERC20()");

        // give vault some tokens
        address payable vaultAddr = payable(address(vault));
        assert(testCoin.balanceOf(vaultAddr) == 0);

        uint256 vaultTokens = 1000;
        testCoin.mint(vaultAddr, vaultTokens); // Give vault some tokens

        console2.log("vault, balance       ", address(vault), testCoin.balanceOf(vaultAddr)) ;
        assert (testCoin.balanceOf(vaultAddr) == vaultTokens);

        // get address for withdrawTo()
        uint256 seed = uint256(keccak256(abi.encodePacked("testSeed")));
        address payable toAddr = payable(vm.addr(seed));

        // Verify token withdrawTo()
        assert(testCoin.balanceOf(vaultAddr) == vaultTokens);
        assert(testCoin.balanceOf(toAddr) == 0);

        vault.withdrawTo(testCoin, toAddr, 100);
        assert(testCoin.balanceOf(toAddr) == 100);
        assert(testCoin.balanceOf(vaultAddr) == vaultTokens - 100);

        // Verify token withdraw()
        vault.withdraw(testCoin, 100);
        assert(testCoin.balanceOf(vaultAddr) == vaultTokens - 200);
        assert(testCoin.balanceOf(owner) == 100);
        console2.log("owner, balance       ", owner, testCoin.balanceOf(owner));

    }
}

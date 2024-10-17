
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@forge-std/console2.sol";
import "@forge-std/Script.sol";
import "@forge-std/Test.sol";
import "../src/core/VaultFactory.sol";
import "../src/interface/IVault.sol";
import {MockEnv} from "./MockEnv.sol";

// Evilcoin is reentrant. Call to transfer will perform reentrant call to vault.execute()

contract EvilCoin is ERC20, Script {
    constructor(uint256 initialSupply) ERC20("EvilCoin", "ECOIN") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        bool beEvil = true;
        if (beEvil) {
            console2.log("Evil: make me some mischief...");
            IVault vault = IVault(payable(msg.sender));
            console2.log("Evil: vault", address(vault));
            uint64 orderIndex;
            uint8 tranche_index;
            PriceProof memory priceProof;
            console2.log("Evil: reentrant call to execute...");
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector); // revert must match exactly
            vault.execute(orderIndex, tranche_index, priceProof);
            console2.log("Evil: mischief detected and inhibited.");
        }
        return (super.transfer(recipient, amount));
    }
}

contract TestReentrancyGuard is Test, MockEnv {

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

    function testReentrancyGuard() public {

        EvilCoin evilCoin = new EvilCoin(0); // Zero tokens to start

        console2.log("testReentrancyGuard()");

        // give vault some tokens
        address payable vaultAddr = payable(address(vault));
        assert(evilCoin.balanceOf(vaultAddr) == 0);

        uint256 vaultTokens = 1000;
        uint256 withdrawTokens = 100;
        evilCoin.mint(vaultAddr, vaultTokens); // Give vault some tokens

        console2.log("vault, balance       ", address(vault), evilCoin.balanceOf(vaultAddr)) ;
        assert (evilCoin.balanceOf(vaultAddr) == vaultTokens);

        vault.withdraw(evilCoin, withdrawTokens); // This one will trigger reentrancy

        assert(evilCoin.balanceOf(vaultAddr) == vaultTokens - withdrawTokens);
        assert(evilCoin.balanceOf(owner) == withdrawTokens);
        console2.log("owner, balance       ", owner, evilCoin.balanceOf(owner));

    }
}

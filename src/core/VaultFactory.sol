
pragma solidity 0.8.26;

import "./Vault.sol";
import "../interface/IVault.sol";
import "../interface/IVaultFactory.sol";
import "../more/Dexorder.sol";

contract VaultFactory is IVaultFactory {

    // The upgrader account may propose upgrades to the VaultImpl delegate contract used by the Vaults created by this
    // VaultFactory. These upgrade proposals take effect only after a long delay, during which time the community can
    // openly review the upgrade for security before it takes effect. Furthermore, each Vault owner must individually
    // approve the upgrade on their Vault for it to take effect.
    address public immutable override upgrader;

    // "Killing" is an extreme countermeasure against either unforeen, unsolvable bugs or a compromising of the upgrader
    // account. Killing causes Vaults to stop forwarding method calls to their VaultImpl proxies, leaving vaults
    // in a deposit/withdraw-only mode, with all executions and order-related operations halted. Killing is
    // irreversible, and a hacker cannot stop the original upgrader account from shutting everything down in such an
    // emergency.
    bool public killed;
    event Killed();

    // This is the common implementation contract, which is the delegate of the vault proxies.  Each created vault
    // keeps its own delegate pointer, and the owner of each vault must explicity opt-in to upgrades (changes) of
    // their vault's implementation.  The _vaultImpl pointed to here is the initial implementation for new vaults and
    // the new implementation for any vaults that authorize an upgrade().
    // The _vaultImpl cannot be changed immediately.  The admin of the VaultFactory proposes a new implementation
    // which is stored in proposedImpl for at least UPGRADE_NOTICE_DURATION seconds before it becomes active as the
    // new implementation.  This gives users and the community time to review any proposed changes before they can be
    // adopted.  Any malicous entity that hacks the Dexorder admin account would also suffer this 30-day delay before
    // their exploit implementation would be used by anyone.  Upgrade proposals are easily, publicly visible by looking
    // for the VaultImplProposed event on-chain.

    // This is the implementation delegate for newly created vaults. Use implementation() to get, then cast to IVaultImpl type.
    address private _vaultImpl;

    // Upgrades
    uint32 public immutable upgradeNoticeDuration;


    // 0 if no upgrade is pending, otherwise the timestamp when proposedImpl becomes the default for new vaults
    uint32 public override proposedImplActivationTimestamp;
    address public override proposedImpl;  // the contract address of a proposed upgrade to the default vault implementation.


    constructor ( address upgrader_, address vaultImpl_, uint32 upgradeNoticeDuration_ ) {
        upgrader = upgrader_;
        _vaultImpl = vaultImpl_;
        upgradeNoticeDuration = upgradeNoticeDuration_;
        // these are all defaults
        // killed = false;
        // proposedImpl = address(0);
        // proposedImplActivationTimestamp = 0;
    }

    struct Parameters {
        address owner;
        uint8 num;
        address vaultImpl;
    }

    Parameters public override parameters;

    function deployVault() public override returns (IVault vault) {
        return _deployVault(msg.sender, 0);
    }

    function deployVault(uint8 num) public override returns (IVault vault) {
        return _deployVault(msg.sender, num);
    }

    function deployVault(address owner) public override returns (IVault vault) {
        return _deployVault(owner, 0);
    }

    function deployVault(address owner, uint8 num) public override returns (IVault vault) {
        return _deployVault(owner, num);
    }

    function _deployVault(address owner, uint8 num) internal returns (IVault vault) {
        // We still allow Vault creation even if the factory has been killed. These vaults will simply be in withdraw
        // only mode. If someone accidentally sends money to their designated vault address but no contract has
        // been created there yet, being able to still deploy a vault will let the owner recover those funds.

        parameters = Parameters(owner, num, _impl());
        // Vault addresses are salted with the owner address and vault number
        vault = IVault(payable(new Vault{salt: keccak256(abi.encodePacked(owner,num))}()));
        delete parameters;
    }


    function _impl() internal returns (address) {
        if (proposedImplActivationTimestamp != 0 && proposedImplActivationTimestamp <= block.timestamp) {
            // time to start using the latest upgrade
            _vaultImpl = proposedImpl;
            proposedImplActivationTimestamp = 0;
            emit IVaultProxy.VaultImplChanged(_vaultImpl);
        }
        return _vaultImpl;
    }


    function implementation() external view override returns (address) {
        return proposedImplActivationTimestamp != 0 && proposedImplActivationTimestamp <= block.timestamp ?
            proposedImpl : _vaultImpl;
    }


    modifier onlyUpgrader() {
        require(msg.sender == upgrader, "not upgrader");
        _;
    }

    function upgradeImplementation( address newImpl ) external onlyUpgrader {
        proposedImpl = newImpl;
        proposedImplActivationTimestamp = uint32(block.timestamp + upgradeNoticeDuration);
        emit IVaultProxy.VaultImplProposed( newImpl, proposedImplActivationTimestamp);
    }

    // If the upgrader ever calls kill(), VaultProxys will stop forwarding calls to the implementation contract. The withdrawal()
    // methods directly implemented on VaultProxy will continue to work.
    // This is intended as a last-ditch safety measure in case the upgrader account was leaked, and a malicious
    // VaultImpl has been proposed and cannot be stopped. In such a case, the entire factory
    // and all of its Vaults executions will be shut down to protect funds. Vault deposit/withdrawal will continue to
    // work normally.
    function kill() external onlyUpgrader {
        killed = true;
        emit Killed();
    }

}

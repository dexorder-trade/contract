// SPDX-License-Identifier: UNLICENSED
pragma solidity ~0.8.22;

import "../interface/IVault.sol";
import {IVaultFactory} from "../interface/IVaultFactory.sol";
import {IFeeManager} from "../interface/IFeeManager.sol";
import {IRouter} from "../interface/IRouter.sol";
pragma abicoder v2;

library ArbitrumOne {
    IVaultFactory internal constant vaultFactory   = IVaultFactory(0x149F2023E04523BF4C2F7dB9a2e8A467AFD2135D);

    IRouter       internal constant arbitrumRouter =       IRouter(0xa695a07b7c586Fa0f2800c1FEfa055c40487Bfe3);
    address       internal constant dexorder       =       address(0x5754523E86d37fE83565F8a63e4883CC971e626A);
    IFeeManager   internal constant feeManager     =   IFeeManager(0xF611915096F4CC4D74e85Eaae185c197317ebC1a);
    address       internal constant queryHelper    =       address(0xF008C17d8C3Bdf52996a4d7caD91e5CC6EFD5DB4);
    IVaultImpl    internal constant vaultImpl      =    IVaultImpl(0x4Bd8221Ec6DBfD3F0aaE29dBfe52FA5B27bcD45C);

    uint256 internal constant VaultInitCodeHash = 0x9e656332e87d8c15e216c0041d06b9de56d05ed4b329dac0f4b578e6bff53619;
}

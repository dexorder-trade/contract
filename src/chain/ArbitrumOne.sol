// SPDX-License-Identifier: UNLICENSED
pragma solidity ~0.8.22;
pragma abicoder v2;

library ArbitrumOne {
    address internal constant VaultFactory      = address(0x149F2023E04523BF4C2F7dB9a2e8A467AFD2135D);
    uint256 internal constant VaultInitCodeHash = 0x9e656332e87d8c15e216c0041d06b9de56d05ed4b329dac0f4b578e6bff53619;

    address internal constant ArbitrumRouter    = address(0xa695a07b7c586Fa0f2800c1FEfa055c40487Bfe3);
    address internal constant Dexorder          = address(0x5754523E86d37fE83565F8a63e4883CC971e626A);
    address internal constant FeeManager        = address(0xF611915096F4CC4D74e85Eaae185c197317ebC1a);
    address internal constant QueryHelper       = address(0xF008C17d8C3Bdf52996a4d7caD91e5CC6EFD5DB4);
    address internal constant VaultImpl         = address(0x4Bd8221Ec6DBfD3F0aaE29dBfe52FA5B27bcD45C);
}

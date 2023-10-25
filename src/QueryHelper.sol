// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
pragma abicoder v2;

import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./OrderLib.sol";
import "./Vault.sol";
import "./VaultDeployer.sol";
import "./Factory.sol";

contract QueryHelper {
    uint8 constant public version = 1;
    uint8 constant public UNKNOWN_DECIMALS = type(uint8).max;

    function getBalances( address vault, address[] memory tokens ) public view
    returns (
        uint256[] memory balances,
        uint256[] memory decimals
    ) {
        require(tokens.length < type(uint16).max);
        balances = new uint256[](tokens.length);
        decimals = new uint256[](tokens.length);
        for( uint16 i=0; i < tokens.length; i++ ) {
            try IERC20(tokens[i]).balanceOf(vault) returns (uint256 balance) {
                balances[i] = balance;
            }
            catch {
                balances[i] = 0;
            }
            try ERC20(tokens[i]).decimals() returns (uint8 dec) {
                decimals[i] = dec;
            }
            catch {
                decimals[i] = UNKNOWN_DECIMALS;
            }
        }
    }

    struct RoutesResult {
        OrderLib.Exchange exchange;
        uint24 fee;
        address pool;
    }

    function getRoutes( address tokenA, address tokenB ) public view
    returns(RoutesResult[] memory routes) {
        // todo discover all supported pools
        // here we find the highest liquidity pool for v2 and for v3
        uint24[4] memory fees = [uint24(100),500,3000,10000];
        uint24 uniswapV2Fee = 0;
        uint128 uniswapV2Liquidity = 0;
        address uniswapV2Pool = address(0);
        uint24 uniswapV3Fee = 0;
        uint128 uniswapV3Liquidity = 0;
        address uniswapV3Pool = address(0);
        for( uint8 f=0; f<4; f++ ) {
            IUniswapV3Pool pool = IUniswapV3Pool(Constants.uniswapV3Factory.getPool(tokenA, tokenB, fees[f]));
            try pool.liquidity() returns (uint128 liquidity) {
                // todo v2
                if( liquidity > uniswapV3Liquidity ) {
                    uniswapV3Fee = fees[f];
                    uniswapV3Liquidity = liquidity;
                    uniswapV3Pool = address(pool);
                }
            }
            catch {
            }
        }
        uint8 routesCount = uniswapV3Fee > 0 ? 1 : 0 + uniswapV2Fee > 0 ? 1 : 0;
        routes = new QueryHelper.RoutesResult[](routesCount);
        uint8 i = 0;
        // todo v2
        if( uniswapV3Fee > 0 )
            routes[i++] = QueryHelper.RoutesResult(OrderLib.Exchange.UniswapV3, uniswapV3Fee, uniswapV3Pool);
    }

    function poolStatus(IUniswapV3Pool pool) public view
    returns (
        int24 tick,
        uint128 liquidity
    ) {
        (, tick,,,,,) = pool.slot0();
        liquidity = pool.liquidity();
    }
}

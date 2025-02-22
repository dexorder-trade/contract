
pragma solidity 0.8.28;

import "@forge-std/console2.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../core/OrderSpec.sol";
import {IVault} from "../interface/IVault.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../core/UniswapV3.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";


contract QueryHelper {
    uint8 constant public version = 1;
    uint8 constant public UNKNOWN_DECIMALS = type(uint8).max;

    IUniswapV3Factory public immutable factory;

    constructor( IUniswapV3Factory factory_ ) {
        factory = factory_;
    }

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
        Exchange exchange;
        uint24 fee;
        address pool;
    }

    function getRoutes( address tokenA, address tokenB ) public view
    returns(RoutesResult[] memory routes) {
        // todo discover all supported pools
        // console2.log('getRoutes');
        // console2.log(tokenA);
        // console2.log(tokenB);
        // here we find the highest liquidity pool for v2 and for v3
        uint24[4] memory fees = [uint24(100),500,3000,10000];
        uint24 uniswapV2Fee = 0;
//        uint128 uniswapV2Liquidity = 0;
//        address uniswapV2Pool = address(0);
        uint24 uniswapV3Fee = 0;
        uint256 uniswapV3Liquidity = 0;
        address uniswapV3Pool = address(0);
        IERC20 ercA = IERC20(tokenA);
        for( uint8 f=0; f<4; f++ ) {
            // console2.log('getPool...');
            uint24 fee = fees[f];
            IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(
                address(UniswapV3Arbitrum.factory), PoolAddress.PoolKey(tokenA, tokenB, fee)));
            if( address(pool) == address(0) ) {
                // console2.log('no pool');
                continue;
            }
            // console2.log('got pool');
            // console2.log(address(pool));
            // NOTE: pool.liquidity() is only the current tick's liquidity, so we look at the pool's balance
            // of one of the tokens as a measure of liquidity
            uint256 liquidity = ercA.balanceOf(address(pool));
            // console2.log(liquidity);
            if( liquidity > uniswapV3Liquidity ) {
                uniswapV3Fee = fee;
                uniswapV3Liquidity = liquidity;
                uniswapV3Pool = address(pool);
            }
        }
        uint8 routesCount = uniswapV3Fee > 0 ? 1 : 0 + uniswapV2Fee > 0 ? 1 : 0;
        // console2.log(uniswapV3Pool);
        // console2.log(uint(routesCount));
        routes = new QueryHelper.RoutesResult[](routesCount);
        uint8 i = 0;
        // todo v2
        if( uniswapV3Fee > 0 )
            routes[i++] = QueryHelper.RoutesResult(Exchange.UniswapV3, uniswapV3Fee, uniswapV3Pool);
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

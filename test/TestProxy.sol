
pragma solidity 0.8.26;

import "@forge-std/console2.sol";
import "@forge-std/Test.sol";

// Inplementaton shared as library

contract Impl {

    // Begin storage shared with Proxy
    uint256 inc;   
    // End storage

    function proxy_target(uint256 x) external view returns(uint256) {
        return(x+inc);
    }
}

// The proxy for the implementation

contract Proxy {
    // Begin storage shared with implementation
    uint256 inc;
    // End storage

    Impl immutable impl; // Address of the library or implementation contract

    constructor(Impl _impl, uint256 _inc) {
        impl = _impl;
        inc = _inc;
    }

    fallback() external payable {
        address _impl = address(impl);
        assembly {
            // Copy the data sent to the memory at position `0`
            calldatacopy(0, 0, calldatasize())
            // Forward the call to the implementation contract with the provided input
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
            // Copy the returned data
            returndatacopy(0, 0, returndatasize())
            // Check if the call was successful and return the data or revert
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

// Interface for Proxy/Implementation

interface IProxy {
    function proxy_target(uint256 x) external returns(uint256);
}

// Test it

contract TestProxy is Test {

    // Create shared implementation

    Impl _impl = new Impl();

    IProxy _proxy;
    IProxy _proxy2;

    function setUp() public {
        // New proxy instance linked to _impl with IProxy interface
        _proxy  = IProxy(address(new Proxy(_impl, 1))); // cannot directly cast Proxy to Iproxy
        _proxy2 = IProxy(address(new Proxy(_impl, 2))); // cannot directly cast Proxy to Iproxy
    }

    function testProxy() public {
        require(_proxy.proxy_target(1)  == 2, "fail");
        require(_proxy2.proxy_target(1) == 3, "fail");
    }

}

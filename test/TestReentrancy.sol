
pragma solidity 0.8.26;

import "@forge-std/console2.sol";
import "@forge-std/Test.sol";

contract ReentrancyContract {
    bool private locked;

    modifier reentrancyProhibited() {
        require(!locked, "Reentrancy prohibited");
        locked = true;
        _;
        locked = false;
    }

    uint256 private foo = 0;
    uint256 private bar = 0;

    function reentrancyProtected() public reentrancyProhibited {
        foo++;
    }

    function reentrancyVulnerable() public {
        bar++;
    }

}

contract TestCosts is Test {

    function setUp() public {
    }

    uint256 constant N = 101;

    function testReentrancy() public {
        ReentrancyContract reentrancyContract = new ReentrancyContract();
        for(uint256 i=0; i<N; i++) {
            reentrancyContract.reentrancyProtected();
            reentrancyContract.reentrancyVulnerable();
        }
    }
}

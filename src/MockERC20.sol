//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockERC20 is ERC20 {

    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_)
    ERC20(name, symbol)
    {
        // _setupDecimals(decimals);
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

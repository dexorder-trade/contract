import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IERC20Metadata.sol";


contract MockERC20 is ERC20, IERC20Metadata {

    constructor(string name, string symbol, uint8 decimals)
    ERC20(name, symbol)
    {
        _setupDecimals(decimals);
    }


    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

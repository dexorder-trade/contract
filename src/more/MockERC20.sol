

pragma solidity 0.8.26;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@forge-std/console2.sol";
import {IERC20Metadata} from "../../lib_uniswap/v3-periphery/contracts/interfaces/IERC20Metadata.sol";


contract MockERC20 is IERC20Metadata {

    // This token allows anyone to mint as much as they desire

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address=>uint256) private _balances;
    mapping(address=>mapping(address=>uint256)) private _allowances;

    constructor(string memory name_, string memory symbol_, uint8 decimals_)
    {
//        console2.log('MockERC20 constructor');
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        totalSupply = 0;
    }

    function mint(address account, uint256 amount) public {
//        console2.log('MockERC20 mint');
        _balances[account] += amount;
        emit Transfer(address(this),account,amount);
    }

    function burn(uint256 amount) public {
//        console2.log('MockERC20 burn');
        require(_balances[msg.sender] >= amount);
        _balances[msg.sender] -= amount;
        emit Transfer(msg.sender,address(this),amount);
    }

    function balanceOf(address account) public view returns (uint256) {
//        console2.log('MockERC20 balance');
        return _balances[account];
    }

    function transfer(address to, uint256 value) public returns (bool) {
//        console2.log('transfer');
//        console2.log(msg.sender);
//        console2.log(to);
//        console2.log(value);
        return _transferFrom(msg.sender, to, value);
    }

    function allowance(address owner, address spender) public view returns (uint256) {
//        console2.log('MockERC20 allowance');
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
//        console2.log('approve');
//        console2.log(msg.sender);
//        console2.log(spender);
//        console2.log(value);
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
//        console2.log('transferFrom');
//        console2.log(msg.sender);
//        console2.log(from);
//        console2.log(to);
//        console2.log(value);
        if( msg.sender != from ) {
//            console2.log('allowance');
//            console2.log(_allowances[from][msg.sender]);
            require(value <= _allowances[from][msg.sender], 'Insufficient allowance');
            if( _allowances[from][msg.sender] != type(uint256).max )
                _allowances[from][msg.sender] -= value;
        }
        return _transferFrom(from, to, value);
    }

    function _transferFrom(address from, address to, uint256 value) private returns (bool) {
//        console2.log('_transferFrom');
//        console2.log(from);
//        console2.log(to);
//        console2.log(value);
//        console2.log(_balances[from]);
        require(_balances[from] >= value, 'Insufficient balance');
        _balances[from] -= value;
        _balances[to] += value;
        emit Transfer(from,to,value);
//        console2.log('raw transfer completed');
        return true;
    }

}

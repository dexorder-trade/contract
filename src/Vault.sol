// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "./Constants.sol";
import "./interface/IVaultDeployer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Vault {
    uint8 public immutable version;
    address public immutable owner;

    constructor()
    {
        (address owner_) = IVaultDeployer(msg.sender).parameters();
        version = Constants.VERSION;
        owner = owner_;
    }

    event DexorderReceived(address, uint256);

    receive() external payable {
        emit DexorderReceived(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        _withdrawNative(msg.sender, amount);
    }

    function withdraw(address payable recipient, uint256 amount) public {
        _withdrawNative(recipient, amount);
    }

    function _withdrawNative(address payable reipient, uint256 amount) internal {
        require(msg.sender == owner);
        reipient.transfer(amount);
    }

    function withdraw(IERC20 token, uint256 amount) public {
        _withdraw(token, msg.sender, amount);
    }

    function withdraw(IERC20 token, address recipient, uint256 amount) public {
        _withdraw(token, recipient, amount);
    }

    function _withdraw(IERC20 token, address recipient, uint256 amount) internal {
        require(msg.sender == owner);
        token.transfer(recipient, amount);
    }

}

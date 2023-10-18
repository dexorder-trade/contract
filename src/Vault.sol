// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "./Constants.sol";
import "./interface/IVaultDeployer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./OrderLib.sol";
import "forge-std/console2.sol";


contract Vault {
    // represents the interests of its owner client

    using OrderLib for OrderLib.OrdersInfo;

    uint8 public immutable version;
    address public immutable owner;
    OrderLib.OrdersInfo public orderList;

    constructor()
    {
        owner = IVaultDeployer(msg.sender).parameters();
        version = Constants.VERSION;
    }

    event DexorderReceived(address, uint256);

    receive() external payable {
        emit DexorderReceived(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        _withdrawNative(msg.sender, amount);
    }

    function withdrawTo(address payable recipient, uint256 amount) public {
        _withdrawNative(recipient, amount);
    }

    function _withdrawNative(address payable reipient, uint256 amount) internal onlyOwner {
        reipient.transfer(amount);
    }

    function withdraw(IERC20 token, uint256 amount) public {
        _withdraw(token, msg.sender, amount);
    }

    function withdrawTo(IERC20 token, address recipient, uint256 amount) public {
        _withdraw(token, recipient, amount);
    }

    function _withdraw(IERC20 token, address recipient, uint256 amount) internal onlyOwner {
        token.transfer(recipient, amount);
    }


    function placeOrder(OrderLib.SwapOrder memory order) public onlyOwner {
        console2.log('Vault.placeOrder()');
        orderList._placeOrder(order);
    }

    function placeOrders(OrderLib.SwapOrder[] memory orders, OrderLib.OcoMode ocoMode) public onlyOwner {
        orderList._placeOrders(orders, ocoMode);
    }

    function swapOrderStatus(uint64 orderIndex) public view returns (OrderLib.SwapOrderStatus memory status) {
        return orderList.orders[orderIndex];
    }

    function execute(uint64 orderIndex, uint8 tranche_index, OrderLib.PriceProof memory proof) public
    {
        orderList.execute(owner, orderIndex, tranche_index, proof);
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

}

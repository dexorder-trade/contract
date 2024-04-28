// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
import "forge-std/console2.sol";
import {FullMath} from '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import {OrderLib} from "./OrderLib.sol";
import {IVault} from "./interface/IVault.sol";
pragma abicoder v2;

// represents the Dexorder organization

contract Dexorder {

    struct FeeSched {
        uint8 fillFeeBP; // fraction of token
        uint8 order;     // native
        uint8 orderExp;
        uint8 tranche;   // native
        uint8 trancheExp;
    }
    FeeSched public feeSched;

    address payable public fillFeeAccount;
    address payable public orderFeeAccount;
    address payable public trancheFeeAccount;

    address _admin;

    modifier onlyAdmin() {
        require(msg.sender == _admin, "not admin");
        _;
    }

    // uint256 constant K = 1<<10;
    function setDebugFeeSched() public {
        feeSched.fillFeeBP = 200; // 200 = 100BP = 1.0%
        // K = 1<<10 = 1024 ~ 1000
        // 1 ETH = 10**18 ~ K**6 ~$2000
        // $0.002 ~ K**4
        feeSched.orderExp = 40; // ~ K**4
        feeSched.order = 100; // ~ $0.20
        feeSched.trancheExp = 40; // ~ K**4
        feeSched.tranche = 100; // ~ $0.20
        console2.log("fill fee (BP):    ", feeSched.fillFeeBP/2);
        console2.log("order fee (wei):  ", feeSched.order   * (1<<feeSched.orderExp));
        console2.log("tranche fee (wei):", feeSched.tranche * (1<<feeSched.trancheExp));
    }

    constructor () {
        _admin = address(0);
        feeSched = FeeSched(0,0,0,0,0);
        orderFeeAccount = payable(address(this));
        trancheFeeAccount = payable(address(this));
        fillFeeAccount = payable(address(this));
    }

    receive() external payable {} // for testing purposes

    function SetFeeSched(FeeSched calldata _feeSched) public onlyAdmin {
        feeSched = _feeSched;
    }

    function setFeeAccounts(address payable _fillFeeAccount, address payable _orderFeeAccount, address payable _trancheFeeAccount) public onlyAdmin {
        fillFeeAccount = _fillFeeAccount;
        orderFeeAccount = _orderFeeAccount;
        trancheFeeAccount = _trancheFeeAccount;
    }

    // Compute absolute fees in native and token units

    function fillFee(uint256 fill, uint8 fillFeeBP) public pure returns(uint256) { // fraction of token
        return FullMath.mulDiv(fill, fillFeeBP, 20000); // fillFeeBP is half a basis point
    }

    function orderFee() public view returns(uint256) { // native
        return uint256(feeSched.order) << feeSched.orderExp;
    }

    function trancheFee(uint256 nTranches) public view returns(uint256) { // native
        return uint256(nTranches * feeSched.tranche) << feeSched.trancheExp;
    }

    // Execution batching

    event DexorderExecutions(bytes16 indexed id, string[] errors);

    struct ExecutionRequest {
        address payable vault;
        uint64 orderIndex;
        uint8 trancheIndex;
        OrderLib.PriceProof proof;
    }


    function execute( bytes16 id, ExecutionRequest memory req ) public returns (string memory error) {
        console2.log('Dexorder execute() single');
        error = _execute(req);
        string[] memory errors = new string[](1);
        errors[0] = error;
        emit DexorderExecutions(id, errors);
        console2.log('Dexorder execute() single completed');
    }


    function execute( bytes16 id, ExecutionRequest[] memory reqs ) public returns (string[] memory errors) {
        console2.log('Dexorder execute() multi');
        console2.log(reqs.length);
        errors = new string[](reqs.length);
        for( uint8 i=0; i<reqs.length; i++ )
            errors[i] = _execute(reqs[i]);
        emit DexorderExecutions(id, errors);
    }


    function _execute( ExecutionRequest memory req ) private returns (string memory error) {
        console2.log('Dexorder _execute()');
        // single tranche execution
        try IVault(req.vault).execute(req.orderIndex, req.trancheIndex, req.proof) {
            error = '';
            console2.log('execution successful');
        }
        catch Error(string memory reason) {
            if( bytes(reason).length == 0 )
                reason = 'UNK';
            console2.log('execute error code');
            console2.log(reason);
            error = reason;
        }
    }
}


pragma solidity 0.8.26;
import "@forge-std/console2.sol";
import "../core/OrderSpec.sol";
import {IVault} from "../interface/IVault.sol";

// represents the Dexorder organization

contract Dexorder {

    address public immutable admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor () {
        admin = address(0);
    }

    receive() external payable {} // for testing purposes


    // Execution batching

    event DexorderExecutions(bytes16 indexed id, string[] errors);

    struct ExecutionRequest {
        address payable vault;
        uint64 orderIndex;
        uint8 trancheIndex;
        PriceProof proof;
    }


    function execute( bytes16 id, ExecutionRequest memory req ) public returns (string memory error) {
        // console2.log('Dexorder execute() single');
        error = _execute(req);
        string[] memory errors = new string[](1);
        errors[0] = error;
        emit DexorderExecutions(id, errors);
        // console2.log('Dexorder execute() single completed');
    }


    function execute( bytes16 id, ExecutionRequest[] memory reqs ) public returns (string[] memory errors) {
        // console2.log('Dexorder execute() multi');
        // console2.log(reqs.length);
        errors = new string[](reqs.length);
        for( uint8 i=0; i<reqs.length; i++ )
            errors[i] = _execute(reqs[i]);
        emit DexorderExecutions(id, errors);
    }


    function _execute( ExecutionRequest memory req ) private returns (string memory error) {
        // console2.log('Dexorder _execute()');
        // single tranche execution
        try IVault(req.vault).execute(req.orderIndex, req.trancheIndex, req.proof) {
            error = '';
            // console2.log('execution successful');
        }
        catch Error(string memory reason) {
            if( bytes(reason).length == 0 )
                reason = 'UNK';
            // console2.log('execute error code');
            // console2.log(reason);
            error = reason;
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.7.6;
pragma solidity >=0.8.0;
import "./OrderLib.sol";
import "./Vault.sol";
pragma abicoder v2;

contract Dexorder {
    // represents the Dexorder organization

    event DexorderExecutions(bytes16 indexed id, string[] errors);

    struct ExecutionRequest {
        address payable vault;
        uint64 orderIndex;
        uint8 trancheIndex;
        OrderLib.PriceProof proof;
    }


    function execute( bytes16 id, ExecutionRequest memory req ) public returns (string memory error) {
        error = _execute(req);
        string[] memory errors = new string[](1);
        errors[0] = error;
        emit DexorderExecutions(id, errors);
    }


    function execute( bytes16 id, ExecutionRequest[] memory reqs ) public returns (string[] memory errors) {
        errors = new string[](reqs.length);
        for( uint8 i=0; i<reqs.length; i++ )
            errors[i] = _execute(reqs[i]);
        emit DexorderExecutions(id, errors);
    }


    function _execute( ExecutionRequest memory req ) private returns (string memory error) {
        // single tranche execution
        try Vault(req.vault).execute(req.orderIndex, req.trancheIndex, req.proof) {
            error = '';
        }
        catch Error(string memory reason) {
            error = reason;
        }
    }
}

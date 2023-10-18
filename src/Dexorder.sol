// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
import "./OrderLib.sol";
import "./Vault.sol";
pragma abicoder v2;

contract Dexorder {
    // represents the Dexorder organization

    event DexorderExecutions(uint128 indexed id, bytes[] errors);

    struct ExecutionRequest {
        address payable vault;
        uint64 orderIndex;
        uint8 trancheIndex;
        OrderLib.PriceProof proof;
    }


    function execute( uint128 id, ExecutionRequest memory req ) public returns (bytes memory error) {
        error = _execute(req);
        bytes[] memory errors = new bytes[](1);
        errors[0] = error;
        emit DexorderExecutions(id, errors);
    }


    function execute( uint128 id, ExecutionRequest[] memory reqs ) public returns (bytes[] memory errors) {
        errors = new bytes[](reqs.length);
        for( uint8 i=0; i<reqs.length; i++ )
            errors[i] = _execute(reqs[i]);
        emit DexorderExecutions(id, errors);
    }


    function _execute( ExecutionRequest memory req ) private returns (bytes memory error) {
        // single tranche execution
        try Vault(req.vault).execute(req.orderIndex, req.trancheIndex, req.proof) {
            return '';
        }
        catch (bytes memory reason) {
            return reason;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

/**
 * @title ZkMinimalAccount
 * @dev This contract implements the IAccount interface for zkSync.
 * It provides minimal functionality for transaction validation and execution.
 * @author Kelechi Kizito Ugwu
 * @notice
 * Phase 1: Validation
 * 1. The user sends the tx to the "zkSync API client" - a light node.
 * 2. The zkSync API client checks to see the nonce is unique by querying the NonceHolder system contract
 * 3. The zkSync API client calls validateTransaction, which MUST update the nonce
 * 4. The zkSync API client checks the nonce is updated
 * 5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
 * 6. The zkSync API client verifies that the bootloader gets paid
 *
 *
 * Phase 2: Execution
 * 7. The zkSync API client passes the validated transaction to the main node / sequencer (as of today, they are the same)
 * 8. The main node calls executeTransaction
 * 9. If a paymaster was used, the postTransaction is called
 */
contract ZkMinimalAccount is IAccount {
    //////////////////////////////////////
    ////// EXTERNAL FUNCTIONS ////////////
    //////////////////////////////////////
    /**
     * @notice must increase the nonce
     * @notice must validate the transaction
     * @param _txHash
     * @param _suggestedSignedHash
     * @param _transaction
     */
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        returns (bytes4 magic)
    {}

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
    {}

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {}

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
    {}

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable
    {}
j
    //////////////////////////////////////
    ////// INTERNAL FUNCTIONS ////////////
    //////////////////////////////////////
}

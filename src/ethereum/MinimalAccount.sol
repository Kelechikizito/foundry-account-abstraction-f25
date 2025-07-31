// SPDX-License-Identifier: MIT

// Layout of the contract file:
// version
// imports
// interfaces, libraries, contract
// errors

// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private

// view & pure functions

pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title MinimalAccount
 * @author Kelechi Kizito Ugwu
 * @notice This contract implements a minimal account that can execute transactions and validate user operations.
 * @dev It inherits from IAccount and Ownable, allowing the owner to execute commands and
 */
contract MinimalAccount is IAccount, Ownable {
    ///////////////////////////////////////////
    //   Errors                              //
    //////////////////////////////////////////
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    ///////////////////////////////////////////
    //   State Variables                      //
    //////////////////////////////////////////
    IEntryPoint private immutable i_entryPoint;

    ///////////////////////////////////////////
    //   Modifier                           //
    //////////////////////////////////////////
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    ///////////////////////////////////////////
    //   Constructor Function               //
    //////////////////////////////////////////
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    ///////////////////////////////////////////
    //   Receive Function                    //
    //////////////////////////////////////////
    receive() external payable {}

    ////////////////////////////
    //   External Functions   //
    ////////////////////////////
    /**
     * @dev This function allows the owner or EntryPoint to execute a function call on a target contract.
     * @notice Executes a function call on the target contract.
     * @param dest The address of the target contract.
     * @param value The amount of Ether to send with the call.
     * @param functionData The data to be sent with the call.
     */
    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);

        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    // A signature is valid, if it is the MinimalAccount owner
    /**
     * @dev This function is called by the EntryPoint contract to validate the user operation.
     * It checks the signature and returns validation data.
     * @param userOp The PackedUserOperation struct containing the user operation details.
     * @param userOpHash The hash of the user operation.
     * @param missingAccountFunds The amount of funds missing from the account.
     * @return validationData The validation data to be returned to the EntryPoint contract.
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    ///////////////////////////////////////////
    //   Private & Internal View Functions   //
    //////////////////////////////////////////
    /**
     * @dev Validates the signature of the user operation.
     * @param userOp The PackedUserOperation struct containing the user operation details.
     * @param userOpHash The hash of the user operation.
     * @return validationData The validation data indicating whether the signature is valid or not.
     */
    // Returns SIG_VALIDATION_SUCCESS if the signature is valid, otherwise returns SIG_VALIDATION_FAILED
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer == address(0) || signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @dev Pays the prefund amount to the EntryPoint contract if missingAccountFunds is not zero.
     * @param missingAccountFunds The amount of funds missing from the account.
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    ///////////////////////////////////////////
    //   Getters                             //
    //////////////////////////////////////////
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}

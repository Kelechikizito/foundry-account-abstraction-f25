// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol"; // Assuming NetworkConfig is defined or imported here
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
// import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    // MinimalAccount minimalAccount;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        address dest = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // Generate the unsigned data
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        // Get the userOp Hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash(); // This step is crucial as it makes the userOpHash EIP-191 compliant, by preppending the 0x19 prefix to the hash and hashinng it again.

        // Sign it, and return it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest); // this cheatcode is used to sign the EIP-191 compliant digest, and returns the signature components v, r and s.
        }
        userOp.signature = abi.encodePacked(r, s, v); // The final signature is constructed using abi.encodePacked(r, s, v). Note the specific order: R, then S, then V. This (RSV) is a common convention for Ethereum signatures when concatenated, but it's important to be aware that vm.sign returns them in VRS order. Getting this order wrong is a common source of signature validation errors.
        return userOp;
    }

    // This helper populates the PackedUserOperation struct without the signature
    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | uint256(callGasLimit)),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32((uint256(maxFeePerGas) << 128) | uint256(maxPriorityFeePerGas)),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
// import {UserOperation} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol"; // Assuming NetworkConfig is defined or imported here
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    // MinimalAccount minimalAccount;
    // 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789

    // function run() public {
    //     HelperConfig helperConfig = new HelperConfig();
    //     address dest = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Ethereum Sepolia Testnet Address USDC
    //     uint256 value = 0;
    //     bytes memory functionData =
    //         abi.encodeWithSelector(IERC20.approve.selector, 0x93923B42Ff4bDF533634Ea71bF626c90286D27A0, 5e6);
    //     bytes memory executeCallData =
    //         abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
    //     PackedUserOperation memory userOp = generateSignedUserOperation(
    //         executeCallData, helperConfig.getConfig(), 0x853Ce3Ed0b8Cd49f0d8655aD9Ba858f7bF44Dc45
    //     );
    //     PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    //     ops[0] = userOp;

    //     vm.startBroadcast();
    //     IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
    //     // vm.stopBroadcast();
    // }

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

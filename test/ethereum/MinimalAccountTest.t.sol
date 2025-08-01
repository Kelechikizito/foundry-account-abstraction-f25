// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {EthRejector} from "test/utils/EthRejector.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;
    EthRejector ethRejector;

    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
        ethRejector = new EthRejector();
    }

    //////////////////////////////////////
    //// Execute Function Tests        ///
    //////////////////////////////////////
    function testOwnerCanExecuteCommands() public {
        // ARRANGE
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // ACT
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        // ASSERT
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // ARRANGE
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // ACT / ASSERT
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    function testExecuteCommandsRevertsIfCallFails() public {
        // ARRANGE
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(ethRejector);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(EthRejector.failMe.selector);
        bytes memory expectedRevertData = abi.encodeWithSignature("Error(string)", "Always fails");

        // ACT / ASSERT
        vm.prank(minimalAccount.owner());
        vm.expectRevert(abi.encodeWithSelector(MinimalAccount.MinimalAccount__CallFailed.selector, expectedRevertData));
        minimalAccount.execute(dest, value, functionData);
    }

    function testEntryPointCanExecuteCommands() public {
        // ARRANGE
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        // bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 startingBalance = 1e18;
        vm.deal(address(minimalAccount), startingBalance);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // ACT
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));

        // ASSERT
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    // function testExecuteCommandsRevertsIfCallFails() public {
    //     // ARRANGE
    //     assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    //     // address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
    //     bytes memory expectedRevertData = abi.encodeWithSignature("Error(string)", "Always fails");

    //     // ACT / ASSERT
    //     vm.prank(minimalAccount.owner());
    //     vm.expectRevert(abi.encodeWithSelector(MinimalAccount.MinimalAccount__CallFailed.selector, expectedRevertData));
    //     minimalAccount.execute(randomUser, value, functionData); // This line did not revert, Isn't this a bug?
    // }

    //////////////////////////////////////
    //// User Operation Tests          ///
    //////////////////////////////////////
    function testRecoverSignedOp() public {
        // ARRANGE
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // ACT
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        // ASSERT
        assertEq(actualSigner, minimalAccount.owner());
    }

    // 1. Sign user ops
    // 2. Call validate userops
    // 3. Assert the return value is correct
    function testValidationOfUserOps() public {
        // ARRANGE
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // ACT
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);

        // ASSERT
        console2.log("Validation Data: ", validationData);
        assertEq(validationData, 0);
    }

    function testValidationOfUserOpsRevertsIfNonOwner() public {
        // ARRANGE
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // ACT / ASSERT
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPoint.selector);
        minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
    }

    //////////////////////////////////////
    //// Getter Functions Tests        ///
    //////////////////////////////////////
    function testGetEntryPoint() public {
        assertEq(minimalAccount.getEntryPoint(), helperConfig.getConfig().entryPoint);
    }
}

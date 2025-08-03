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
    DeployMinimal deployMinimal;

    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        deployMinimal = new DeployMinimal();
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

    function testValidationRevertsForNonOwnerSigner() public {
        // ARRANGE - Use a completely different address as signer
        (address randomSigner, uint256 randomPrivateKey) = makeAddrAndKey("randomSigner");

        // Create a simple hash to sign
        bytes32 testHash = keccak256("test message");
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(testHash);

        // Sign with the random private key (not the owner)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomPrivateKey, ethSignedMessageHash);

        PackedUserOperation memory packedUserOp;
        packedUserOp.signature = abi.encodePacked(r, s, v);

        uint256 missingAccountFunds = 0;

        // ACT
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, testHash, missingAccountFunds);

        // ASSERT - This MUST hit the SIG_VALIDATION_FAILED path
        assertEq(validationData, 1);
    }

    //////////////////////////////////////
    //// Getter Functions Tests        ///
    //////////////////////////////////////
    function testGetEntryPoint() public {
        assertEq(minimalAccount.getEntryPoint(), helperConfig.getConfig().entryPoint);
    }

    function testMinimalAccountCanRecieveEther() public {
        // ARRANGE
        uint256 sendValue = 1e18;
        vm.deal(randomUser, sendValue); // Give some ether to the random user
        uint256 initialBalance = address(minimalAccount).balance;

        // ACT
        vm.prank(randomUser);
        (bool success,) = address(minimalAccount).call{value: sendValue}("");
        uint256 endingBalance = address(minimalAccount).balance;

        // ASSERT
        assertEq(success, true);
        assertEq(endingBalance, initialBalance + sendValue);
    }

    function testDeployMinimalRun() public {
        // ACT - Call the run function directly
        (HelperConfig returnedConfig, MinimalAccount returnedAccount) = deployMinimal.run();

        // ASSERT - Verify the deployment worked
        assertNotEq(address(returnedConfig), address(0));
        assertNotEq(address(returnedAccount), address(0));

        // Verify the account is properly configured
        assertNotEq(returnedAccount.owner(), address(this));
        assertNotEq(returnedAccount.getEntryPoint(), address(0));

        // Verify the config is valid
        HelperConfig.NetworkConfig memory config = returnedConfig.getConfig();
        assertNotEq(config.entryPoint, address(0));
        assertNotEq(config.account, address(0));
    }

    function testHelperConfig() public {
        // ARRANGE
        (HelperConfig returnedConfig, MinimalAccount returnedAccount) = deployMinimal.run();
        HelperConfig.NetworkConfig memory config = returnedConfig.getConfig();
        HelperConfig.NetworkConfig memory localConfig = returnedConfig.getOrCreateAnvilEthConfig();

        // ACT

        // ASSERT
        console2.log("Local Config Account", localConfig.account);
        assertEq(abi.encodePacked(localConfig.account), abi.encodePacked(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainId.selector);
        returnedConfig.getConfigByChainId(9999); // Invalid chain ID
    }

    function testHelperConfigTwo() public {
        // ARRANGE
        (HelperConfig returnedConfig, MinimalAccount returnedAccount) = deployMinimal.run();
        HelperConfig.NetworkConfig memory config = returnedConfig.getConfig();
        HelperConfig.NetworkConfig memory localConfig = returnedConfig.getOrCreateAnvilEthConfig();

        // ACT
        returnedConfig.getConfigByChainId(11155111); // Invalid chain ID

        // ASSERT
        assertNotEq(abi.encodePacked(localConfig.account), abi.encodePacked(address(0)));
    }

    function testGenerateSignedUserOperation_OnAnvil() public {
        // This test will naturally hit the IF branch when run on Anvil (chainid 31337)
        // ARRANGE
        console2.log("Current chain ID:", block.chainid);

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        // ACT
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );

        // ASSERT
        assertTrue(packedUserOp.signature.length > 0, "Signature should not be empty");
        assertEq(packedUserOp.signature.length, 65, "Signature should be 65 bytes long");

        // Verify the signature by recovering the signer
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        address recoveredSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        if (block.chainid == 31337) {
            // Should be signed with ANVIL_DEFAULT_KEY (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
            assertEq(
                recoveredSigner,
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                "Should use Anvil default key on chain 31337"
            );
            console2.log("IF branch tested - using ANVIL_DEFAULT_KEY");
        } else {
            // Should be signed with config.account
            console2.log("ELSE branch tested - using config.account");
            assertTrue(recoveredSigner != address(0), "Recovered signer should not be zero");
        }
    }

    // function testGenerateSignedUserOperation_OnSepoliaEth() public {
    //     // Skip if not running fork tests
    //     vm.chainId(11155111);
    //     if (block.chainid == 31337) {
    //         console2.log("Skipping fork test on Anvil");
    //         return;
    //     }

    //     // This would test the ELSE branch on a mainnet fork
    //     address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
    //     bytes memory executeCallData =
    //         abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

    //     PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
    //         executeCallData, helperConfig.getConfig(), address()
    //     );

    //     assertTrue(packedUserOp.signature.length > 0, "Signature should not be empty on mainnet fork");
    //     console2.log("ELSE branch tested on chain ID:", block.chainid);
    // }
}

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

# Foundry Account Abstraction

A minimal demonstration of **Account Abstraction** (AA) on Ethereum and zkSync using Foundry, featuring two minimal account contracts that implement core AA logic for each chain.

This project is based on the exact tutorial from Cyfrin Updraft:  
[https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction/introduction](https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction/introduction)

---

## 📜 Overview

Account Abstraction (AA) enables users to control their Ethereum or Layer 2 accounts with smart contract wallets that can validate transactions and pay fees in flexible ways.

This project demonstrates the **basic AA functionality** on:

- **Ethereum (Sepolia testnet)** via the ERC-4337 standard using an **EntryPoint** contract and a `MinimalAccount` smart wallet.
- **zkSync Era** testnet, which has **native AA support**, using a `ZkMinimalAccount` smart wallet interacting directly with zkSync system contracts.

The purpose is to show how AA concepts are the same across chains but differ in implementation details — zkSync simplifies AA by integrating it natively, while Ethereum requires more manual handling.

---

## 🔍 Side-by-Side Account Abstraction Comparison

| Concept                    | Ethereum: MinimalAccount                                                                            | zkSync Era: ZkMinimalAccount                                                                        |
| -------------------------- | --------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Transaction Validation** | Via `validateUserOp` called by EntryPoint; signature verified using `ECDSA.recover` on `userOpHash` | Via `validateTransaction` called by Bootloader; signature verified directly on transaction hash     |
| **Nonce Management**       | Implicit in userOp; EntryPoint tracks nonces                                                        | Explicit nonce increment via `INonceHolder` system contract call                                    |
| **Fee Payment**            | Prefund sent to EntryPoint if needed in `validateUserOp`                                            | Fees paid to bootloader in `payForTransaction` function                                             |
| **Execution**              | `execute` function called by EntryPoint or owner; forwards calls                                    | `executeTransaction` called by Bootloader or owner; performs low-level calls with revert on failure |
| **Caller Authentication**  | Requires caller to be EntryPoint or owner                                                           | Requires caller to be Bootloader or owner                                                           |

---

### Ethereum Example — Signature Validation Snippet

```solidity
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
````

---

### zkSync Example — Signature Validation Snippet

```solidity
function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
    // Increment nonce via NonceHolder system contract
    SystemContractsCaller.systemCallWithPropagatedRevert(
        uint32(gasleft()),
        address(NONCE_HOLDER_SYSTEM_CONTRACT),
        0,
        abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
    );

    // Check for sufficient balance omitted for brevity

    bytes32 txHash = _transaction.encodeHash();
    address signer = ECDSA.recover(txHash, _transaction.signature);
    bool isValidSigner = signer == owner();

    if (isValidSigner) {
        magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
    } else {
        magic = bytes4(0);
    }
    return magic;
}
```

---

## 🚀 Deployment & Usage

### Ethereum (Sepolia) Deployment

Use Foundry scripts in `script/DeployMinimalAccount.s.sol` (not included here) with the command:

```bash
forge script script/DeployMinimalAccount.s.sol:DeployMinimalAccount \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $DEPLOYER_KEY \
  --broadcast
```

**Important disclaimer:**
The EntryPoint contract deployed on Ethereum Sepolia testnet is **not compatible** with the version of the `account-abstraction` package used here.
Sepolia’s EntryPoint uses `UserOperation` structs, but this project uses `PackedUserOperation` — a difference that breaks compatibility.
This is a known issue specific to Sepolia and does not affect all L1 or L2 chains.

### zkSync Era Deployment

Deployment for zkSync Era is **not included** due to current incompatibilities with Foundry scripting support on zkSync.
zkSync’s native account abstraction and system contracts require more complex deployment workflows beyond the scope of this project.

---

## ✅ Testing

Run unit tests with Foundry as usual:

```bash
forge test -vv
```

Tests cover key functionality including signature validation, nonce handling, execution, and security checks for both account types.

---

## 🔒 Security Considerations

* Signature verification is strict and uses OpenZeppelin’s `ECDSA` library.
* Nonce management prevents replay attacks (handled differently on each chain).
* Only owner or system contracts (EntryPoint/Bootloader) may trigger critical functions.
* Ether handling uses safe `call` patterns with error checks.

---

## 📚 References

* Cyfrin Updraft Account Abstraction Tutorial: [https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction/introduction](https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction/introduction)
* ERC-4337 Spec (Ethereum AA): [https://eips.ethereum.org/EIPS/eip-4337](https://eips.ethereum.org/EIPS/eip-4337)
* zkSync Era Docs: [https://era.zksync.io/docs/](https://era.zksync.io/docs/)
* OpenZeppelin ECDSA Library: [https://docs.openzeppelin.com/contracts/4.x/api/cryptography#ECDSA](https://docs.openzeppelin.com/contracts/4.x/api/cryptography#ECDSA)
* Foundry Book: [https://book.getfoundry.sh/](https://book.getfoundry.sh/)

---

## 📄 License

This project is licensed under the MIT License.


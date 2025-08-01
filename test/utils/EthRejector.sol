// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract EthRejector {
    function failMe() external pure {
        revert("Always fails");
    }
}

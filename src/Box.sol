// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private s_value;

    event ValueChanged(uint256 indexed value);

    constructor(uint256 initialValue, address initialOwner) Ownable(initialOwner) {
        s_value = initialValue;
    }

    function updateValue(uint256 newValue) external {
        s_value = newValue;
        emit ValueChanged(newValue);
    }

    function getValue() external view returns (uint256) {
        return s_value;
    }
}

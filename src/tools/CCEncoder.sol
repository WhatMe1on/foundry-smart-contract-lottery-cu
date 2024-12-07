// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

library CCEncoder {
    function castFlag(bool flag) public pure returns (bytes memory output) {
        output = flag ? bytes("1") : bytes("0");
    }

    function castFlags(
        bool[] memory flags
    ) public pure returns (bytes memory output) {
        output = "";
        for (uint256 i = 0; i < flags.length; i++) {
            output = bytes.concat(output, castFlag(flags[i]));
        }
    }

    function castFlags(
        bool[4] memory flags
    ) public pure returns (bytes memory output) {
        output = "";
        for (uint256 i = 0; i < flags.length; i++) {
            output = bytes.concat(output, castFlag(flags[i]));
        }
    }
}

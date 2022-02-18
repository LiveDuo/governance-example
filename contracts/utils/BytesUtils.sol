// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BytesUtils {
    function bytesToHexString(bytes memory _calldata) public pure returns (string memory) {

        string memory strx = "0x";

        for (uint i = 0; i < _calldata.length; i++) {
            uint8 bb = uint8(bytes1(_calldata[i]));

            if (bb / 16 >= 10) {
                uint x1 = 97 + ((bb / 16) - 10);
                if (bb % 16 < 10) {
                    uint x2 = 48 + (bb % 16);
                    strx = string(abi.encodePacked(strx, x1, x2));
                } else {
                    uint x2 = 97 + ((bb % 16) - 10);
                    strx = string(abi.encodePacked(strx, x1, x2));
                }
            } else {
                uint x1 = 48 + (bb / 16);
                if (bb % 16 < 10) {
                    uint x2 = 48 + (bb % 16);
                    strx = string(abi.encodePacked(strx, x1, x2));
                } else {
                    uint x2 = 97 + ((bb % 16) - 10);
                    strx = string(abi.encodePacked(strx, x1, x2));
                }
            }

        }
        return strx;
    }
}
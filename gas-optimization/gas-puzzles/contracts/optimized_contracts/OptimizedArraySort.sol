// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

contract OptimizedArraySort {
    function sortArray(
        uint256[] calldata data
    ) external pure returns (uint256[] memory) {
        uint256 dataLen = data.length;

        // Create 'working' copy
        uint256[] memory _data = new uint256[](dataLen);
        for (uint256 k = 0; k < dataLen; ) {
            _data[k] = data[k];
            unchecked {
                ++k;
            }
        }

        for (uint256 i = 0; i < dataLen; ) {
            uint256 current = _data[i];
            for (uint256 j = i + 1; j < dataLen; ) {
                uint256 next = _data[j];
                if (current > next) {
                    _data[j] = current;
                    current = next;
                }
                unchecked {
                    ++j;
                }
            }
            _data[i] = current;

            unchecked {
                ++i;
            }
        }
        return _data;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

contract OptimizedArraySort {
    function sortArray(uint256[] calldata data) external pure returns (uint256[] memory) {
        uint256 dataLen = data.length;

        // Create 'working' copy
        uint[] memory _data = new uint256[](dataLen);
        for (uint256 k = 0; k < dataLen;) {
            _data[k] = data[k];
            unchecked{
                ++k;
            }
        }

        for (uint256 i = 0; i < dataLen;) {
            for (uint256 j = i+1; j < dataLen;) {
                uint256 a = _data[i];
                uint256 b = _data[j];

                if(a > b){
                   _data[i] = b;
                   _data[j] = a;
                }
                unchecked {
                    ++j;
                }
            }
            unchecked{
                ++i;
            }
        }
        return _data;
    }
}

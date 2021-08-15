// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

library RandomPower {
    function _numbers() internal pure returns (uint16[99] memory numbers) {
        numbers[0] = 99;
        numbers[1] = 197;
        numbers[2] = 294;
        numbers[3] = 390;
        numbers[4] = 485;
        numbers[5] = 579;
        numbers[6] = 672;
        numbers[7] = 764;
        numbers[8] = 855;
        numbers[9] = 945;
        numbers[10] = 1034;
        numbers[11] = 1122;
        numbers[12] = 1209;
        numbers[13] = 1295;
        numbers[14] = 1380;
        numbers[15] = 1464;
        numbers[16] = 1547;
        numbers[17] = 1629;
        numbers[18] = 1710;
        numbers[19] = 1790;
        numbers[20] = 1869;
        numbers[21] = 1947;
        numbers[22] = 2024;
        numbers[23] = 2100;
        numbers[24] = 2175;
        numbers[25] = 2249;
        numbers[26] = 2322;
        numbers[27] = 2394;
        numbers[28] = 2465;
        numbers[29] = 2535;
        numbers[30] = 2604;
        numbers[31] = 2672;
        numbers[32] = 2739;
        numbers[33] = 2805;
        numbers[34] = 2870;
        numbers[35] = 2934;
        numbers[36] = 2997;
        numbers[37] = 3059;
        numbers[38] = 3120;
        numbers[39] = 3180;
        numbers[40] = 3239;
        numbers[41] = 3297;
        numbers[42] = 3354;
        numbers[43] = 3410;
        numbers[44] = 3465;
        numbers[45] = 3519;
        numbers[46] = 3572;
        numbers[47] = 3624;
        numbers[48] = 3675;
        numbers[49] = 3725;
        numbers[50] = 3774;
        numbers[51] = 3822;
        numbers[52] = 3869;
        numbers[53] = 3915;
        numbers[54] = 3960;
        numbers[55] = 4004;
        numbers[56] = 4047;
        numbers[57] = 4089;
        numbers[58] = 4130;
        numbers[59] = 4170;
        numbers[60] = 4209;
        numbers[61] = 4247;
        numbers[62] = 4284;
        numbers[63] = 4320;
        numbers[64] = 4355;
        numbers[65] = 4389;
        numbers[66] = 4422;
        numbers[67] = 4454;
        numbers[68] = 4485;
        numbers[69] = 4515;
        numbers[70] = 4544;
        numbers[71] = 4572;
        numbers[72] = 4599;
        numbers[73] = 4625;
        numbers[74] = 4650;
        numbers[75] = 4674;
        numbers[76] = 4697;
        numbers[77] = 4719;
        numbers[78] = 4740;
        numbers[79] = 4760;
        numbers[80] = 4779;
        numbers[81] = 4797;
        numbers[82] = 4814;
        numbers[83] = 4830;
        numbers[84] = 4845;
        numbers[85] = 4859;
        numbers[86] = 4872;
        numbers[87] = 4884;
        numbers[88] = 4895;
        numbers[89] = 4905;
        numbers[90] = 4914;
        numbers[91] = 4922;
        numbers[92] = 4929;
        numbers[93] = 4935;
        numbers[94] = 4940;
        numbers[95] = 4944;
        numbers[96] = 4947;
        numbers[97] = 4949;
        numbers[98] = 4950;
    }

    function findPower(uint256 number) internal pure returns (uint256 power) {
        uint16[99] memory numbers = _numbers();

        uint16 low = 0;
        uint16 high = 99;

        uint16 index = 0;
        while(low <= high) {
            uint16 mid = (high + low) / 2;
            uint16 guess = numbers[mid];

            if (guess == uint16(number)) {
                return uint256(mid + 1);
            } else if (guess > uint16(number)) {
                high = mid - 1;
            } else {
                low = mid + 1;
            }
            index++;
        }
        return uint256(low + 1);
    }
}

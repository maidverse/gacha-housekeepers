// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

library RandomPower {
    //for gas saving, separate numbers[] into 5 functions.
    function _numbers1() internal pure returns (uint16[20] memory numbers) {
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
    }

    function _numbers2() internal pure returns (uint16[20] memory numbers) {
        numbers[0] = 1869;
        numbers[1] = 1947;
        numbers[2] = 2024;
        numbers[3] = 2100;
        numbers[4] = 2175;
        numbers[5] = 2249;
        numbers[6] = 2322;
        numbers[7] = 2394;
        numbers[8] = 2465;
        numbers[9] = 2535;
        numbers[10] = 2604;
        numbers[11] = 2672;
        numbers[12] = 2739;
        numbers[13] = 2805;
        numbers[14] = 2870;
        numbers[15] = 2934;
        numbers[16] = 2997;
        numbers[17] = 3059;
        numbers[18] = 3120;
        numbers[19] = 3180;
    }

    function _numbers3() internal pure returns (uint16[20] memory numbers) {
        numbers[0] = 3239;
        numbers[1] = 3297;
        numbers[2] = 3354;
        numbers[3] = 3410;
        numbers[4] = 3465;
        numbers[5] = 3519;
        numbers[6] = 3572;
        numbers[7] = 3624;
        numbers[8] = 3675;
        numbers[9] = 3725;
        numbers[10] = 3774;
        numbers[11] = 3822;
        numbers[12] = 3869;
        numbers[13] = 3915;
        numbers[14] = 3960;
        numbers[15] = 4004;
        numbers[16] = 4047;
        numbers[17] = 4089;
        numbers[18] = 4130;
        numbers[19] = 4170;
    }

    function _numbers4() internal pure returns (uint16[20] memory numbers) {
        numbers[0] = 4209;
        numbers[1] = 4247;
        numbers[2] = 4284;
        numbers[3] = 4320;
        numbers[4] = 4355;
        numbers[5] = 4389;
        numbers[6] = 4422;
        numbers[7] = 4454;
        numbers[8] = 4485;
        numbers[9] = 4515;
        numbers[10] = 4544;
        numbers[11] = 4572;
        numbers[12] = 4599;
        numbers[13] = 4625;
        numbers[14] = 4650;
        numbers[15] = 4674;
        numbers[16] = 4697;
        numbers[17] = 4719;
        numbers[18] = 4740;
        numbers[19] = 4760;
    }

    function _numbers5() internal pure returns (uint16[20] memory numbers) {
        numbers[0] = 4779;
        numbers[1] = 4797;
        numbers[2] = 4814;
        numbers[3] = 4830;
        numbers[4] = 4845;
        numbers[5] = 4859;
        numbers[6] = 4872;
        numbers[7] = 4884;
        numbers[8] = 4895;
        numbers[9] = 4905;
        numbers[10] = 4914;
        numbers[11] = 4922;
        numbers[12] = 4929;
        numbers[13] = 4935;
        numbers[14] = 4940;
        numbers[15] = 4944;
        numbers[16] = 4947;
        numbers[17] = 4949;
        numbers[18] = 4950;
    }

    function _findPower(
        uint16 number,
        uint16[20] memory numbers,
        uint16 diff
    ) internal pure returns (uint256 power) {
        uint16 low = 0;
        uint16 high = 19;

        uint16 index = 0;
        while (low <= high) {
            uint16 mid = (high + low) / 2;
            uint16 guess = numbers[mid];

            if (guess == number) {
                return uint256(mid + 1 + diff);
            } else if (guess > number) {
                high = mid - 1;
            } else {
                low = mid + 1;
            }
            index++;
        }
        return uint256(low + 1 + diff);
    }

    function findPower(uint256 number) internal pure returns (uint256 power) {
        if (number <= 1790) return _findPower(uint16(number), _numbers1(), 0);
        else if (number <= 3180) return _findPower(uint16(number), _numbers2(), 20);
        else if (number <= 4170) return _findPower(uint16(number), _numbers3(), 40);
        else if (number <= 4760) return _findPower(uint16(number), _numbers4(), 60);
        else return _findPower(uint16(number), _numbers5(), 80);
    }
}

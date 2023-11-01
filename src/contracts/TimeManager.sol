//SPDX-License-Identifier: Unlicense
//github.com/pipermerriam/ethereum-datetime/blob/master/contracts/DateTime.sol
pragma solidity >=0.7.0 <0.9.0;

contract TimeManager {

    struct Time {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
        uint8 weekday;
    }

    uint256 constant daySeconds = 86400;
    uint256 constant yearSeconds = 31536000;
    uint256 constant leapYearSeconds = 31622400;

    uint16 constant originyear = 1970;

    function isLeapYear(uint16 year) public pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }

        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }

        return true;
    }

    function toTimestamp(  //mod86400
        uint16 year,
        uint8 month,
        uint8 day
    ) public pure returns (uint256 timestamp) {
        uint16 i;

        // Year
        for (i = originyear; i < year; i++) {
            if (isLeapYear(i)) {
                timestamp += leapYearSeconds;
            } else {
                timestamp += yearSeconds;
            }
        }

        // Month
        uint8[12] memory monthDays;
        monthDays[0] = 31;
        if (isLeapYear(year)) {
            monthDays[1] = 29;
        } else {
            monthDays[1] = 28;
        }
        monthDays[2] = 31;
        monthDays[3] = 30;
        monthDays[4] = 31;
        monthDays[5] = 30;
        monthDays[6] = 31;
        monthDays[7] = 31;
        monthDays[8] = 30;
        monthDays[9] = 31;
        monthDays[10] = 30;
        monthDays[11] = 31;

        for (i = 1; i < month; i++) {
            timestamp += daySeconds * monthDays[i - 1];
        }

        // Day
        timestamp += daySeconds * (day - 1);

        return timestamp;
    }

    function marume86400 (uint256 timestamp) public pure returns (uint256) {
        return (timestamp - (timestamp % 86400));
    }
}

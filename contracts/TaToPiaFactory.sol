// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import './TaToPia.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract TaToPiaFactory {
    TaToPia[] public villages;
    address public potatoAddress;

    using Counters for Counters.Counter;
    Counters.Counter private villageCounter;

    IERC20 private POTATO;

    constructor (address _potato) {
        potatoAddress = _potato;
        POTATO = IERC20(_potato);
    }

    function createVillage() external {
        uint256 _villageNumber = villageCounter.current();
        TaToPia _village = new TaToPia(potatoAddress, _villageNumber);
        villages.push(_village);
        villageCounter.increment();
    }

    function getVillages() public view returns (TaToPia[] memory) {
        return villages;
    }

    function createLand(uint256 _villageNumber, uint256 _startTime) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.createLand(_startTime);
    }

    function invest(uint256 _villageNumber, uint256 _landNumber, uint256 _amount) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.invest(msg.sender, _landNumber, _amount);
    }

    function reinvest(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        (uint256 _investedLand, uint256 _amount) = _village.reinvest(msg.sender, _landNumber);
        // TODO ^ can state changing functions return values?
    }

    function optOut(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.optOut(msg.sender, _landNumber);
    }

    function optOutWithdraw(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.optOutWithdraw(msg.sender, _landNumber);
    }


    function refundSeedFail(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.refundSeedFail(msg.sender, _landNumber);
    }

    function migrateSeedFail(uint256 _villageNumber) external {
        bool _seedingStatus = villages[_villageNumber].getSeeedingStatus();
        uint256 _amount = 
        require(!_seedingStatus, "Seeding is successful");

        uint256 flag = 0;
        for (i == _villageNumber+1; i <= villageCounter; i++) {
            bool _isAvailable = villages[i].isAvailableToMigrate();
            if (_isAvailable) {
                TaToPia _village = TaToPia(villages[i]);
                _village.migration(msg.sender, );
            }
        }
    }

    // TODO: referral
}
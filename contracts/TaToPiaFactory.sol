// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import './TaToPia.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract TaToPiaFactory {
    TaToPia[] public villages;
    address public potatoAddress;

    uint256 public villageCounter = 0;

    IERC20 private POTATO;

    constructor (address _potato) {
        potatoAddress = _potato;
        POTATO = IERC20(_potato);
    }

    function createVillage() external {
        // TODO village name
        TaToPia _village = new TaToPia(potatoAddress, villageCounter);
        villages.push(_village);
        villageCounter += 1;
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

        uint256 _allowance = POTATO.allowance(msg.sender, address(this));
        require(_allowance >= _amount, "Not enough token allowance");

        POTATO.transferFrom(msg.sender, address(_village), _amount);
        _village.invest(msg.sender, _landNumber, _amount);
    }

    function proceedToNextPhase(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.proceedToNextPhase(_landNumber);
    } 

    function reinvest(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        (uint256 _investedLand, uint256 _amount) = _village.reinvest(msg.sender, _landNumber);
        // TODO ^ state changing functions macam cannot return values
    }

    function optOut(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.optOut(msg.sender, _landNumber);
    }

    function optOutWithdraw(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.optOutWithdraw(msg.sender, _landNumber);
    }


    function refundSeedFail(uint256 _villageNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.refundSeedFail(msg.sender);
    }

    function migrateSeedFail(uint256 _villageNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        ( , bool _seedingStatus) = _village.getSeedingStatus();
        require(!_seedingStatus, "Seeding is successful");
        uint256 _amount = _village.getSeedFailRefundAmount(msg.sender);
        require(_amount > 0, "Your migratable amount is 0");
        
        // find new village and migrate
        for (uint256 i = _villageNumber+1; i <= villageCounter; i++) {
            bool _isAvailable = villages[i].isAvailableToMigrate(_amount);
            if (_isAvailable) {
                TaToPia _migrateVillage = TaToPia(villages[i]);
                _migrateVillage.migration(msg.sender, _amount);
            }
        }
    }

    // TODO: referral
}
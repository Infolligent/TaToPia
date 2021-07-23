// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./TaToPia.sol";

contract TaToPiaFactory {
    TaToPia[] public villageAddresses;
    address public potatoAddress;

    constructor (address _potato) {
        potatoAddress = _potato;
    }

    function createVillage() external {
        TaToPia village = new TaToPia(potatoAddress);
        villageAddresses.push(village);
    }

    function invest(uint256 _villageNumber, uint256 _landNumber, uint256 _amount) external {
        TaToPia _village = TaToPia(villageAddresses[_villageNumber]);
        _village.invest(msg.sender, _landNumber, _amount);
    }

    function reinvest(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villageAddresses[_villageNumber]);
        _village.reinvest(msg.sender, _landNumber);
        // TODO
    }

    function optOut(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villageAddresses[_villageNumber]);
        _village.optOut(msg.sender, _landNumber);
    }

    function optOutWithdraw(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villageAddresses[_villageNumber]);
        _village.optOutWithdraw(msg.sender, _landNumber);
    }


    function refundSeedFail(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villageAddresses[_villageNumber]);
        _village.refundSeedFail(msg.sender, _landNumber);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import './TaToPia.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TaToPiaFactory {
    struct Player {
        address upline;
        address[] downlines;
        uint256 directDownlinesInvestment;
        uint256 withdrawableBonus;
    }

    mapping(address => Player) public players;
    address[] public playerList;

    TaToPia[] public villages;
    address public potatoAddress;
    uint256 potatoDecimal;

    uint256 public villageCounter = 0;

    ERC20 private POTATO;
    uint256[] private REFERRAL_BONUS = [20, 20,20, 10, 10, 10, 5, 5, 5, 5, 5, 5];
    uint256[] private BONUS_UNLOCK = [3000, 4500, 7000, 10000, 15000, 25000, 40000, 60000, 90000, 135000, 200000, 300000];

    constructor (address _potato) {
        potatoAddress = _potato;
        POTATO = ERC20(_potato);
        potatoDecimal = POTATO.decimals();
    }

    function createVillage(string memory _villageName) external {
        TaToPia _village = new TaToPia(potatoAddress, _villageName, villageCounter);
        villages.push(_village);
        villageCounter += 1;
    }

    function getVillages() public view returns (TaToPia[] memory) {
        return villages;
    }

    function createLand(uint256 _villageNumber, string memory _landName, uint256 _startTime) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.createLand(_startTime, _landName);
    }

    function invest(address _upline, uint256 _villageNumber, uint256 _landNumber, uint256 _amount) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);

        uint256 _allowance = POTATO.allowance(msg.sender, address(this));
        require(_allowance >= _amount, "Not enough token allowance");

        POTATO.transferFrom(msg.sender, address(_village), _amount);
        _village.invest(msg.sender, _landNumber, _amount);

        addReferrer(msg.sender, _upline);
        addBonus(msg.sender, _amount);
    }

    function proceedToNextPhase(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        _village.proceedToNextPhase(_landNumber);
    } 

    function reinvest(uint256 _villageNumber, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[_villageNumber]);
        (uint256 _investedLand, uint256 _amount) = _village.reinvest(msg.sender, _landNumber);
        addBonus(msg.sender, _amount);
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

    /*************************************
        Referral system 
    *************************************/
    function isCircularReference(address upline, address downline) internal view returns(bool) {
        return players[upline].upline == downline;
    }

    function addReferrer(address _player, address _upline) internal returns(bool){
        if (_upline == address(0)) {
            //emit RegisteredRefererFailed(msg.sender, referrer, "Referrer cannot be 0x0 address");
            //return false;
        } else if (isCircularReference(_upline, _player)) {
            //emit RegisteredRefererFailed(msg.sender, referrer, "Referee cannot be one of referrer uplines");
            return false;
        } else if (players[_player].upline != address(0)) {
            //emit RegisteredRefererFailed(msg.sender, referrer, "Address have been registered upline");
            return false;
        }

        Player storage userAccount = players[_player];
        Player storage uplineAccount = players[_upline];

        userAccount.upline = _upline;
        uplineAccount.downlines.push(_player);

        // emit RegisteredReferer(msg.sender, referrer);
        return true;
    }

    function addBonus(address _player, uint256 _amount) internal {
        address _downline = _player;
        address _upline;

        for (uint i = 0; i < 12; i++) {
            _upline = players[_downline].upline;

            // TODO break if default upline is reached
            if (_upline == address(0)) {
                break;
            }

            Player storage uplineAccount = players[_upline];

            if (i == 0) {
                uplineAccount.directDownlinesInvestment += _amount;
            }

            // add bonus if unlocked
            uint256 bonus_unlock = BONUS_UNLOCK[i] * (10 ** potatoDecimal);
            if (uplineAccount.directDownlinesInvestment >= bonus_unlock) {
                uplineAccount.withdrawableBonus += _amount * REFERRAL_BONUS[i] / 1000;
            }

            _downline = _upline;
        }
    }

    /*************************************
        View Functions 
    *************************************/
    function getPlayerInvestments(address _player) external view returns (uint256[][] memory) {
        // returns the invested amount of player at each land of each village
        uint256[][] memory _investments = new uint256[][](villageCounter);
        for (uint256 i = 0; i < villageCounter; i++) {
            TaToPia _village = TaToPia(villages[i]);
            uint256[] memory _villageInvestment = _village.getInvestments(_player);
            _investments[i] = _villageInvestment;
        }

        return _investments;
    }

    function getUpline(address _player) external view returns(address) {
        return players[_player].upline;
    }

    function getWithdrawableBonus(address _player) external view returns(uint256) {
        return players[_player].withdrawableBonus;
    }
}
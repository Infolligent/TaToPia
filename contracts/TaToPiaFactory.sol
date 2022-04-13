// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./TaToPia.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TaToPiaFactory is Ownable {
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
    uint256 _potatoDecimal;

    uint256 public villageCounter = 0;

    ERC20 private _token;
    uint256[] private REFERRAL_BONUS = [20, 20, 20, 10, 10, 10, 5, 5, 5, 5, 5, 5];
    uint256[] private BONUS_UNLOCK = [
        3000,
        4500,
        7000,
        10000,
        15000,
        25000,
        40000,
        60000,
        90000,
        135000,
        200000,
        300000
    ];

    constructor(address _potato) {
        potatoAddress = _potato;
        _token = ERC20(_potato);
        _potatoDecimal = _token.decimals();
    }

    function createVillage(string memory _villageName) external onlyOwner {
        if (villageCounter > 0) {
            TaToPia latestVillage = villages[villageCounter - 1];
            require(latestVillage.getLandCounter() > 4, 'Previous village has less than 4 lands');
        }
        TaToPia _village = new TaToPia(potatoAddress, _villageName, villageCounter);
        villages.push(_village);
        villageCounter += 1;
    }

    function createLand(
        uint256 villageNumber_,
        string memory landName_,
        uint256 startTime_
    ) external onlyOwner {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        _village.createLand(startTime_, landName_);
    }

    function invest(
        address upline_,
        uint256 villageNumber_,
        uint256 _landNumber,
        uint256 amount_
    ) external {
        // TODO: require invesment in all previous existing villages
        TaToPia _village = TaToPia(villages[villageNumber_]);

        uint256 _allowance = _token.allowance(msg.sender, address(this));
        require(_allowance >= amount_, "Not enough token allowance");

        _token.transferFrom(msg.sender, address(_village), amount_);
        uint256 amount = _village.invest(msg.sender, _landNumber, amount_);
        
        // Overpaid
        if (amount < amount_) {
            uint256 refundableAmount = amount_ - amount;
            _token.transferFrom(address(_village), msg.sender, refundableAmount);
        }

        _addReferrer(msg.sender, upline_);
        _addBonus(msg.sender, amount_);
    }

    function proceedToNextPhase(uint256 villageNumber_, uint256 _landNumber) external onlyOwner {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        _village.proceedToNextPhase(_landNumber);
    }

    function reinvest(uint256 villageNumber_, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        (uint256 _investedLand, uint256 amount_) = _village.reinvest(msg.sender, _landNumber);
        // TODO: add event on _investedLand and amount_
        _addBonus(msg.sender, amount_);
    }

    function optOut(uint256 villageNumber_, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        _village.optOut(msg.sender, _landNumber);
    }

    function optOutWithdraw(uint256 villageNumber_, uint256 _landNumber) external {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        _village.optOutWithdraw(msg.sender, _landNumber);
    }

    function refundSeedFail(uint256 villageNumber_) external {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        _village.refundSeedFail(msg.sender);
    }

    function migrateSeedFail(uint256 villageNumber_) external {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        (, bool _seedingStatus) = _village.getSeedingStatus();
        require(!_seedingStatus, "Seeding is successful");
        uint256 amount_ = _village.getSeedFailRefundAmount(msg.sender);
        require(amount_ > 0, "Your migratable amount is 0");

        // find new village and migrate
        for (uint256 i = villageNumber_ + 1; i <= villageCounter; i++) {
            bool _isAvailable = villages[i].isAvailableToMigrate(amount_);
            if (_isAvailable) {
                TaToPia _migrateVillage = TaToPia(villages[i]);
                _migrateVillage.migration(msg.sender, amount_);
            }
        }
    }

    function getPlayerInvestments(address player_) external view returns (uint256[][] memory) {
        // returns the invested amount of player_ at each land of each village
        uint256[][] memory _investments = new uint256[][](villageCounter);
        for (uint256 i = 0; i < villageCounter; i++) {
            TaToPia _village = TaToPia(villages[i]);
            uint256[] memory _villageInvestment = _village.getInvestments(player_);
            _investments[i] = _villageInvestment;
        }

        return _investments;
    }

    function getPlayerReinvested(uint256 villageNumber_, uint256 landNumber_, address player_) external view returns (bool) {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        return _village.getPlayerReinvested(landNumber_, player_);
    }

    function getPlayerOptedOut(uint256 villageNumber_, uint256 landNumber_, address player_) external view returns (bool) {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        return _village.getPlayerOptedOut(landNumber_, player_);
    }

    function getPlayerWithdrawn(uint256 villageNumber_, uint256 landNumber_, address player_) external view returns (bool) {
        TaToPia _village = TaToPia(villages[villageNumber_]);
        return _village.getPlayerWithdrawn(landNumber_, player_);
    }

    function getUpline(address player_) external view returns (address) {
        return players[player_].upline;
    }

    function getWithdrawableBonus(address player_) external view returns (uint256) {
        return players[player_].withdrawableBonus;
    }

    function getVillages() public view returns (TaToPia[] memory) {
        return villages;
    }

    /*************************************
        Referral system 
    *************************************/
    function _addBonus(address player_, uint256 amount_) internal {
        address _downline = player_;
        address upline_;

        for (uint256 i = 0; i < 12; i++) {
            upline_ = players[_downline].upline;

            // TODO break if default upline is reached
            if (upline_ == address(0)) {
                break;
            }

            Player storage _uplineAccount = players[upline_];

            // add bonus if unlocked
            uint256 _bonusUnlock = BONUS_UNLOCK[i] * (10**_potatoDecimal);
            uint256 _directDownlineInv = _uplineAccount.directDownlinesInvestment;
            if (_directDownlineInv <= _bonusUnlock) {
                if (i == 0) {
                    if (_directDownlineInv + amount_ > _bonusUnlock) {
                        uint256 _balanceBonus = _directDownlineInv + amount_ - _bonusUnlock;
                        _uplineAccount.withdrawableBonus += (_balanceBonus * REFERRAL_BONUS[i]) / 1000;
                    }
                    _uplineAccount.directDownlinesInvestment += amount_;
                }
            } else {
                _uplineAccount.withdrawableBonus += (amount_ * REFERRAL_BONUS[i]) / 1000;
            }

            _downline = upline_;
        }
    }

    function _addReferrer(address player_, address upline_) internal returns (bool) {
        if (upline_ == address(0)) {
            //emit RegisteredRefererFailed(msg.sender, referrer, "Referrer cannot be 0x0 address");
            //return false;
        } else if (_isCircularReference(upline_, player_)) {
            //emit RegisteredRefererFailed(msg.sender, referrer, "Referee cannot be one of referrer uplines");
            return false;
        } else if (players[player_].upline != address(0)) {
            //emit RegisteredRefererFailed(msg.sender, referrer, "Address have been registered upline");
            return false;
        }

        Player storage userAccount = players[player_];
        Player storage uplineAccount = players[upline_];

        userAccount.upline = upline_;
        uplineAccount.downlines.push(player_);

        // emit RegisteredReferer(msg.sender, referrer);
        return true;
    }

    function _isCircularReference(address upline_, address downline_) internal view returns (bool) {
        return players[upline_].upline == downline_;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// docs: https://docs.google.com/document/d/1g6WP1H0lS1s48IJ-GeCGYRelvQ7BOt8EHeqVsHA0xHE/edit

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TaToPia is Ownable {
    enum Phases {
        Seeding,
        Calculate,
        Budding,
        Flowering,
        Harvest,
        Sales,
        Failed
    }

    struct Player {
        address playerAddress;
        address upline;
        address[] downlines;
    }

    struct Land {
        string name;
        uint256 landNumber;
        uint256 seedStart;
        uint256 seedEnd;
        uint256 phaseStartTime;
        uint256 phaseEndTime;
        uint256 target;
        uint256 funded; // new player + reinvestment + migrations
        uint256 reinvested; // total reinvestment amount from previous lands
        uint256 migrated;
        bool hit;
        Phases phase;
        mapping(address => uint256) invested;
        mapping(address => bool) playerExist;
        address[] playersList;
        mapping(address => uint256) playersIndex;
        mapping(address => bool) isReinvestFromT2; // keeps track if the user is reinvested FROM the T-2 land
        mapping(address => bool) isReinvest; // keeps track if user already reinvest TO new land
        mapping(address => bool) seedFailRefunded;
        mapping(address => bool) optedOut;
        mapping(address => bool) optOutWithdraw;
        address[] optOutList;
    }

    uint256 public landCounter;
    mapping(uint256 => Land) public lands;

    mapping(address => bool) _globalPlayerExist;
    mapping(address => Player) _players;
    Player[] public globalPlayersList;

    uint256 constant public MAX_INT = type(uint256).max;

    uint256 private _initialSeedTarget = 10000 ether; // assume Potato token is 18 decimals

    IERC20 private _token;
    uint256 public _villageNumber;
    string public _villageName;

    constructor(
        address potato_,
        string memory villageName_,
        uint256 villageNumber_
    ) {
        _token = IERC20(potato_);
        _villageName = villageName_;
        _villageNumber = villageNumber_;

        _token.approve(msg.sender, MAX_INT);
    }

    function createLand(uint256 startTime_, string memory name_) public {
        // Previous land must be fully seeded
        if (landCounter > 0) {
            require(lands[landCounter - 1].hit, "Previous land has not hit seeding target");
        }

        // Land T-3 must finish calculating
        if (landCounter > 3) {
            require(uint256(lands[landCounter - 3].phase) > 1, "Land T-3 Calculation phase not done");
        }

        uint256 _target;
        if (landCounter >= 1) {
            uint256 _previousTarget = lands[landCounter - 1].target;
            _target = (_previousTarget / 100) * 130;
        } else {
            _target = _initialSeedTarget;
        }

        // initialize a land, starts at seeding phase
        Land storage _land = lands[landCounter];
        _land.name = name_;
        _land.landNumber = landCounter;

        if ((landCounter + 1) % 4 == 0) {
            require(lands[landCounter - 3].hit, "T-3 land has not fully seeded");
        }

        if (landCounter == 0) {
            _land.phaseStartTime = startTime_;
            _land.seedStart = startTime_;
        } else {
            _land.phaseStartTime = block.timestamp;
            _land.seedStart = block.timestamp;
        }

        // TODO: 3 and 4 days may need to swap
        if (landCounter == 0) {
            _land.phaseEndTime = startTime_ + 2 weeks - 1 hours;
            _land.seedEnd = startTime_ + 2 weeks - 1 hours;
        } else if (landCounter % 2 == 0) {
            _land.phaseEndTime = lands[landCounter - 1].seedEnd + 3 days;
            _land.seedEnd = lands[landCounter - 1].seedEnd + 3 days;
        } else {
            _land.phaseEndTime = lands[landCounter - 1].seedEnd + 4 days;
            _land.seedEnd = lands[landCounter - 1].seedEnd + 4 days;
        }
        _land.target = _target;
        _land.phase = Phases.Seeding;

        landCounter++;
    }

    function proceedToNextPhase(uint256 landNumber) public {
        Land storage _land = lands[landNumber];

        require(_land.phase != Phases.Sales, "This land is completed");
        uint256 _endTime = _land.phaseEndTime;

        if (_land.phase == Phases.Seeding) {
            // proceed to Calculate phase after seeding
            require(block.timestamp >= _endTime, "Not the time yet");
            if (_land.funded < _land.target) {
                _land.phaseEndTime = MAX_INT;
                _land.phase = Phases.Failed;
                return;
            }
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = _land.phaseStartTime + 1 hours;
        } else if (_land.phase == Phases.Calculate) {
            // proceed to Budding phase
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = _land.phaseStartTime + 2 days + 15 hours;
        } else if (_land.phase == Phases.Budding) {
            // proceeds to flowering phase (decision making)
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = _land.phaseStartTime + 8 hours;
        } else if (_land.phase == Phases.Flowering) {
            // proceeds to harvesting
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = _land.phaseStartTime + 4 days + 1 hours;
        } else if (_land.phase == Phases.Harvest) {
            // proceeds to Sales
            // time is set to indefinite
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = MAX_INT;
        }
        _land.phase = Phases(uint256(_land.phase) + 1);
    }

    function invest(
        address _player,
        uint256 _landNumber,
        uint256 _amount
    ) external onlyOwner returns (uint256) {
        Land storage _land = lands[_landNumber];
        require(_landNumber < landCounter, "Not a valid land number");
        require(_land.phase == Phases.Seeding, "This land is not currently in seeding phase");
        require(block.timestamp >= _land.phaseStartTime, "Land is not started yet");

        // TODO: default upline?
        // require(_globalPlayerExist[_upline] || _upline == address(0), "Upline does not exist");

        // 0.1% of target
        uint256 _pointOne = _land.target / 1000;
        uint256 _minInvest;
        if (_pointOne < 1000 ether) {
            _minInvest = _pointOne;
        } else {
            _minInvest = 1000 ether;
        }
        uint256 _maxInvest = (_land.target * 5) / 100;

        uint256 _invested = _land.invested[_player];
        require(_invested + _amount <= _maxInvest, "Seeding amount exceeds maximum");
        require(_invested + _amount >= _minInvest, "Seeding amount is less than minimum");

        if (_land.funded + _amount > _land.target) {
            _amount = _land.target - _land.funded;
        }

        if (!_land.playerExist[_player]) {
            _land.playerExist[_player] = true;
            _land.playersList.push(_player);
            _land.playersIndex[_player] = _land.playersList.length;
        }

        _land.invested[_player] += _amount;
        _land.funded += _amount;
        if (_land.funded == _land.target) {
            _land.hit = true;
        }
        return _amount;
    }

    // reinvest
    function reinvest(address _player, uint256 _landNumber) external onlyOwner returns (uint256, uint256) {
        // _landNumber is the CURRENT land number
        // reinvestment will be bring forward to the new land
        Land storage _land = lands[_landNumber];
        require(_land.phase >= Phases.Flowering, "It is not the flowering phase");
        require(_land.playerExist[_player], "You are not in this land");
        require(!_land.optedOut[_player], "You have already opt out");
        require(!_land.isReinvest[_player], "You already reinvested");
        require((landCounter - _landNumber) >= 2, "New land is not created yet");

        _land.isReinvest[_player] = true;
        uint256 _investment = _land.invested[_player];
        uint256 _newInvestment = (_investment * 115) / 100;

        for (uint256 i = _landNumber + 2; i < landCounter; i++) {
            // still seeding
            if (block.timestamp < lands[i].seedEnd && !lands[i].hit) {
                Land storage _newLand = lands[i];
                _newLand.playerExist[_player] = true;
                _newLand.playersList.push(_player);
                _newLand.playersIndex[_player] = _newLand.playersList.length;
                _newLand.invested[_player] = _newInvestment;
                _newLand.funded += _newInvestment;
                _newLand.reinvested += _newInvestment;

                if (_newLand.funded == _newLand.target) {
                    _newLand.hit = true;
                }

                if (i == _landNumber + 2) {
                    _newLand.isReinvestFromT2[_player] = true;
                }
                return (i, _newInvestment);
            }
        }

        revert("No new land to reinvest yet");
    }

    function migration(address _player, uint256 _amount) external onlyOwner {
        // investment migrated from a previous village that has failed seeding phase

        Land storage _land = lands[landCounter - 1];
        // this check is probably duplicated since isAvailableToMigrate already ran, probably don't need
        // uint256 _migratedAmount = _land.migrated;
        // uint256 _twentyPercent = _land.target * 20 / 100;
        // require(_migratedAmount + _amount > _twentyPercent, "Reinvestment exceeds 20% threshold");

        if (!_land.playerExist[_player]) {
            _land.playerExist[_player] = true;
            _land.playersList.push(_player);
            _land.playersIndex[_player] = _land.playersList.length;
        }

        _land.invested[_player] += _amount;
        _land.funded += _amount;
        if (_land.funded == _land.target) {
            _land.hit = true;
        }

        _land.migrated += _amount;
    }

    // withdraw decision
    function optOut(address _player, uint256 _landNumber) external onlyOwner {
        Land storage _land = lands[_landNumber];
        require(_land.phase == Phases.Flowering, "It is not the flowering phase");
        require(_land.playerExist[_player], "You are not in this land");
        require(!_land.optedOut[_player], "You have already opt out");
        require(!_land.isReinvest[_player], "You already reinvested");

        // add to opt out list
        _land.optedOut[_player] = true;
        _land.optOutList.push(_player);

        // Remove player from list if opt out

        // uint256 _index = _land.playersIndex[_player];
        // address _lastPlayer = _land.playersList[_land.playersList.length - 1];
        // _land.playersList[_index] = _lastPlayer;
        // _land.playersIndex[_player] = MAX_INT;
        // _land.playersIndex[_lastPlayer] = _index;
        // _land.playerExist[_player] = false;
        // _land.playersList.pop();
    }

    // withdraw at the end of cycle
    function optOutWithdraw(address _player, uint256 _landNumber) external onlyOwner {
        Land storage _land = lands[_landNumber];
        require(_land.phase == Phases.Sales, "It is not the sales phase");
        require(_land.optedOut[_player], "You are still in the game");
        require(!_land.optOutWithdraw[_player], "You have already withdraw");

        uint256 _invested = _land.invested[_player];
        uint256 _withdrawable = (_invested / 100) * 115;

        _land.optOutWithdraw[_player] = true;

        _token.transfer(_player, _withdrawable);
    }

    function getContractPTTBalance() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /*************************************
        Handle seed fail
    *************************************/
    function getSeedingStatus() public view returns (uint256, bool) {
        // Returns seeding status of latest land, returns:
        // 1. Latest land number
        // 2. Seeding status: True = seed successful, False = Seed fail
        if (landCounter == 0) {
            return (0, false);
        }
        uint256 _landNumber = landCounter - 1;
        Land storage _land = lands[_landNumber];

        //require(block.timestamp > _land.seedEnd, "Seeding phase is not over yet");
        if (_land.hit) {
            return (_landNumber, true);
        } else {
            return (_landNumber, false);
        }
    }

    function isAvailableToMigrate(uint256 _amount) public view returns (bool) {
        // takes in the amount that the player wants to migrate and returns if
        // there is available space to migrate

        (uint256 _landNumber, bool _seedingStatus) = getSeedingStatus();
        Land storage _land = lands[_landNumber];
        uint256 _funded = _land.funded;
        uint256 _target = _land.target;
        uint256 _twentyPercent = (_target * 100) / 20; // 20% of land's target
        uint256 _migrated = _land.migrated;

        if (!_seedingStatus || _amount <= _target - _funded || _migrated + _amount <= _twentyPercent) {
            return true;
        } else {
            return false;
        }
    }

    function getSeedFailRefundAmount(address _player) public view returns (uint256) {
        // If land T seeding fail:
        // 1. Land T new players get 100% refund
        // 2. T-3 players get refunds proportion to the amount they invest
        // (T-3) refund = invested / _T3Total * _refundProportion

        (uint256 _landNumber, bool _seedingStatus) = getSeedingStatus();
        require(!_seedingStatus, "Seeding target is reached");
        Land storage _land = lands[_landNumber];

        uint256 _contractBalance = getContractPTTBalance();
        uint256 _refundProportion = _contractBalance - _land.funded; // refundable amount for T-3 players
        uint256 _T3Total = lands[_landNumber - 1].funded +
            lands[_landNumber - 2].funded +
            lands[_landNumber - 3].funded;

        uint256 _refund = 0;
        if (_land.playerExist[_player]) {
            _refund += _land.invested[_player];
        }

        if (landCounter > 3) {
            for (uint256 i = _landNumber - 1; i >= _landNumber - 3; i--) {
                if (i == _landNumber - 3) {
                    // user reinvested from T-2 land, i.e. 2 to 4, so skip 2 to prevent duplicate refund
                    if (lands[_landNumber].isReinvestFromT2[_player]) {
                        break;
                    }
                }
                if (lands[i].playerExist[_player] || lands[i].optedOut[_player]) {
                    _refund += (lands[i].invested[_player] / _T3Total) * _refundProportion;
                }
            }
        }

        return _refund;
    }

    function refundSeedFail(address _player) external onlyOwner {
        (uint256 _landNumber, bool _seedingStatus) = getSeedingStatus();
        require(!_seedingStatus, "Seeding target is reached");

        Land storage _land = lands[_landNumber];
        require(!_land.seedFailRefunded[_player], "You already withdraw your refund");

        uint256 _refundable = getSeedFailRefundAmount(_player);
        require(_refundable > 0, "Your refundable amount if 0");
        _land.seedFailRefunded[_player] = true;
        _token.transfer(_player, _refundable);
    }

    /*************************************
        View Functions 
    *************************************/
    function getLandCounter() external view returns (uint256) {
        return landCounter;
    }

    function getInvestments(address _player) external view returns (uint256[] memory) {
        uint256[] memory _investments = new uint256[](landCounter);
        for (uint256 i = 0; i < landCounter; i++) {
            _investments[i] = lands[i].invested[_player];
        }

        return _investments;
    }

    function getPlayerReinvested(uint256 _landNumber, address _player) external view returns (bool) {
        Land storage _land = lands[_landNumber];
        return _land.isReinvest[_player];
    }

    function getPlayerOptedOut(uint256 _landNumber, address _player) external view returns (bool) {
        Land storage _land = lands[_landNumber];
        return _land.optedOut[_player];
    }

    function getPlayerWithdrawn(uint256 _landNumber, address _player) external view returns (bool) {
        Land storage _land = lands[_landNumber];
        return _land.optOutWithdraw[_player];
    }
}

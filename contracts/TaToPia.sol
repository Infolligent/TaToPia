// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// docs: https://docs.google.com/document/d/1g6WP1H0lS1s48IJ-GeCGYRelvQ7BOt8EHeqVsHA0xHE/edit

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract TaToPia {
    
    enum Phases { Seeding, Calculate, Budding, Flowering, Harvest, Sales }
    
    struct Player {
        address playerAddress;
        address upline;
        address[] downlines;
        uint256 downlineProfits;  // TODO: how are these calculated?
    }
    
    struct Land {
        uint256 landNumber;
        uint256 seedStart;
        uint256 seedEnd;
        uint256 phaseStartTime;
        uint256 phaseEndTime;
        uint256 target;
        uint256 funded;
        bool hit;
        
        Phases phase;
        
        mapping (address => uint256) invested;
        mapping (address => bool) playerExist;
        address[] playersList;    
        
        mapping (address => bool) isReinvestFromT_2;
        mapping (address => bool) reinvested;
        uint256 reinvestment;   // reinvestment amount
        mapping (address => bool) seedFailRefunded;
        
        mapping (address => uint256) playersIndex;
        mapping (address => bool) optedOut;
        mapping (address => bool) optOutWithdraw;
        address[] optOutList;
    }
    
    uint256 public landLength;
    mapping (uint256 => Land) public lands;
    
    mapping (address => bool) globalPlayerExist;
    mapping (address => Player) players;
    Player[] public globalPlayersList;
    
    uint256 maxInt = 2**256 - 1;
    
    uint256 private InitialSeedTarget = 10000 ether;  // assume Potato token is 18 decimals
    uint256 contractBalance;
    
    IERC20 private POTATO;
    
    constructor(address _potato) {
        POTATO = IERC20(_potato);
    }
    
    function createLand(uint256 _startTime) public {
        
        // Land T-3 must be fully seeded before starting new land
        if (landLength > 3) {
            require(lands[landLength-3].funded >= lands[landLength-3].target, "Land T-3 is not fully seeded yet");
        }
        // Previous land must be fully seeded
        if (landLength > 0) {
            require(lands[landLength-1].hit, "Previous land is not fully seeded yet");
        }

        uint256 _target;
        if (landLength >= 2) {
            uint256 _previousTarget = lands[landLength-1].target;
            _target = _previousTarget / 100 * 130;
        } else {
            _target = InitialSeedTarget; 
        }
        
        // initialize a land, starts at seeding phase
        Land storage _land = lands[landLength];
        _land.landNumber = landLength;
        _land.phaseStartTime = _startTime;  // TODO: block.timestamp for landLength > 1?
        _land.seedStart = _startTime;
        if (landLength == 0) {
            _land.phaseEndTime = _startTime + 2 weeks - 1 hours;
            _land.seedEnd = _startTime + 2 weeks - 1 hours;
        } else if (landLength%2 == 0) {
            _land.phaseEndTime = lands[landLength-1].phaseEndTime + 3 days;
            _land.seedEnd = lands[landLength-1].phaseEndTime + 3 days;
        } else {
            _land.phaseEndTime = lands[landLength-1].phaseEndTime + 4 days;
            _land.seedEnd = lands[landLength-1].phaseEndTime + 4 days;
        }
        _land.target = _target;
        _land.phase = Phases.Seeding;
        
        landLength++;
    }
    
    function proceedToNextPhase(uint256 _landNumber) public {
        Land storage _land = lands[_landNumber];
        
        require(_land.phase != Phases.Sales, "This land is completed");
        uint256 _endTime = _land.phaseEndTime;
        
        // TODO: put the correct time
        if (_land.phase == Phases.Seeding) {
            // proceed to Calculate phase after seeding
            require(block.timestamp >= _endTime, "Not the time yet");
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
            _land.phaseEndTime = _land.phaseStartTime + 1 weeks;
        } else if (_land.phase == Phases.Harvest) {
            // proceeds to Sales
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = maxInt;
        } 
        _land.phase = Phases(uint(_land.phase) + 1);
        
    }
    
    function invest(uint256 _landNumber, address _upline, uint256 _amount) external {
        Land storage _land = lands[_landNumber];
        require(_landNumber < landLength, "Not a valid land number");
        require(_land.phase == Phases.Seeding, "This land is not currently in seeding phase");
        require(block.timestamp >= _land.phaseStartTime, "Land is not started yet");

        // TODO: default upline?
        require(globalPlayerExist[_upline] || _upline == address(0), "Upline does not exist");
        
        // 0.1% of target
        uint256 _pointOne = _land.target / 1000;
        uint256 _minInvest;
        if (_pointOne < 1000 ether) {
            _minInvest = _pointOne;
        } else {
            _minInvest = 1000 ether;
        }
        uint256 _maxInvest = _land.target * 5 / 100;

        uint256 _invested = _land.invested[msg.sender];
        require(_invested + _amount <= _maxInvest, "Seeding amount exceeds maximum");
        require(_invested + _amount >= _minInvest, "Seeding amount is less than minimum");
        
        uint256 _allowance = POTATO.allowance(msg.sender, address(this));
        require(_allowance >= _amount, "Not enough token allowance");
        if (_land.funded + _amount > _land.target) {
            _amount = _land.target - _land.funded;
        }

        POTATO.transferFrom(msg.sender, address(this), _amount);
        
        address[] memory _downlines;
        if (!globalPlayerExist[msg.sender]) {
            Player memory _player = Player({
                playerAddress: msg.sender,
                upline: _upline,
                downlineProfits: 0,
                downlines: _downlines
            });
            
            globalPlayersList.push(_player);
            globalPlayerExist[msg.sender] = true;
            players[msg.sender] = _player;
            
            if (_upline != address(0)) {
                players[_upline].downlines.push(msg.sender);
            }
        }
        
        if (!_land.playerExist[msg.sender]) {
            _land.playerExist[msg.sender] = true;
            _land.playersList.push(msg.sender);
            _land.playersIndex[msg.sender] = _land.playersList.length;
        }
        
        _land.invested[msg.sender] += _amount;
        _land.funded += _amount;
        if (_land.funded == _land.target) {
            _land.hit = true;
        }
        contractBalance += _amount;
    }

    // reinvest
    function reinvest(uint256 _landNumber, address _player) external {
        // _landNumber is the CURRENT land number
        // reinvestment will be bring forward to the new land
        Land storage _land = lands[_landNumber];
        require(_land.phase == Phases.Flowering, "It is not the flowering phase");
        require(_land.playerExist[_player], "You are not in this land");
        require(_land.optedOut[_player], "You have already opt out");
        require(!_land.reinvested[_player], "You already reinvested");
        require((landLength-_landNumber) >= 2, "New land is not created yet");

        uint256 _investment = _land.invested[_player];
        uint256 _newInvestment = _investment * 115 / 100;

        for (uint256 i=_landNumber+2; i<landLength; i++) {
            // still seeding
            if (block.timestamp < lands[i].seedEnd && !lands[i].hit) {
                Land storage _newLand = lands[i];
                _newLand.playerExist[_player] = true;
                _newLand.playersList.push(_player);
                _newLand.playersIndex[_player] = _newLand.playersList.length;
                _newLand.invested[_player] = _newInvestment;
                _newLand.funded += _newInvestment;
                _newLand.reinvestment += _newInvestment;

                if (i == _landNumber+2) {
                    _newLand.isReinvestFromT_2[msg.sender] = true;
                }
                break;
            }
            // TODO: handle no land to reinvest
        }    
    }
    
    // withdraw decision
    function optOut(uint256 _landNumber) external {
        Land storage _land = lands[_landNumber];
        require(_land.phase == Phases.Flowering, "It is not the flowering phase");
        require(_land.playerExist[msg.sender], "You are not in this land");
        require(!_land.optedOut[msg.sender], "You have already opt out");
        require(!_land.reinvested[msg.sender], "You already reinvested");
        
        // add to opt out list
        _land.optedOut[msg.sender] = true;
        _land.optOutList.push(msg.sender);
        
        uint256 _index = _land.playersIndex[msg.sender];
        address _lastPlayer = _land.playersList[_land.playersList.length - 1];
        _land.playersList[_index] = _lastPlayer;
        _land.playersIndex[msg.sender] = maxInt;
        _land.playersIndex[_lastPlayer] = _index;
        _land.playerExist[msg.sender] = false;
        _land.playersList.pop();
    }
    
    // withdraw at the end of cycle
    function withdraw(uint256 _landNumber) external {
        Land storage _land = lands[_landNumber];
        require(_land.phase == Phases.Sales, "It is not the sales phase");
        require(_land.optedOut[msg.sender], "You are still in the game");
        require(!_land.optOutWithdraw[msg.sender], "You have already withdraw");
        
        uint256 _invested = _land.invested[msg.sender];
        uint256 _withdrawable = _invested / 100 * 115;
        
        _land.optOutWithdraw[msg.sender] = true;
        contractBalance -= _withdrawable;
        
        // Don't need to check contract balance as it will have enough
        POTATO.transfer(msg.sender, _withdrawable);
    }

    function getContractPTTBalance() public view returns(uint256) {
        return POTATO.balanceOf(address(this));
    }

    function getSeedFailRefundAmount(address _player, uint256 _landNumber) public view returns (uint256) {
        // If land T seeding fail:
        // 1. Land T new players get 100% refund
        // 2. T-3 players get refunds proportion to the amount they invest
        // (T-3) refund = invested / _T3Total * _refundProportion

        Land storage _land = lands[_landNumber];
        require(block.timestamp > _land.seedEnd, "Seeding has not end yet");
        require(!_land.hit, "Seeding target is reached");

        uint256 _contractBalance = getContractPTTBalance();
        uint256 _refundProportion = _contractBalance - _land.funded;  // refundable amount for T-3 players
        uint256 _T3Total = lands[_landNumber-1].funded + lands[_landNumber-2].funded + lands[_landNumber-3].funded;

        uint256 _refund = 0;
        if (_land.playerExist[_player]) {
            _refund += _land.invested[_player];
        } 
        
        if (landLength > 3) {
            for (uint256 i=_landNumber-1; i>=_landNumber-3; i--) {
                if (i == _landNumber-3) {
                    if (lands[_landNumber].isReinvestFromT_2[_player]) {
                        break;
                    }
                }
                if (lands[i].playerExist[_player] || lands[i].optedOut[_player]) {
                    _refund += lands[i].invested[_player] / _T3Total * _refundProportion;
                }
            }
        }

        return _refund;
    }
    
    // handle seeding fail
    function refundSeedFail(uint256 _landNumber) external {
        Land storage _land = lands[_landNumber];
        require(_landNumber < landLength, "Not a valid land number");
        require(block.timestamp >= _land.seedEnd, "Seeding is not over yet");
        require(!_land.hit, "Seeding is successful");
        require(!_land.seedFailRefunded[msg.sender], "You already withdraw your refund");

        uint256 _refundable = getSeedFailRefundAmount(msg.sender, _landNumber);
        _land.seedFailRefunded[msg.sender] = true;
        POTATO.transfer(msg.sender, _refundable);
    }
}


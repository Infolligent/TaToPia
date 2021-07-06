// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// docs: https://docs.google.com/document/d/1g6WP1H0lS1s48IJ-GeCGYRelvQ7BOt8EHeqVsHA0xHE/edit

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract TaToPia {
    
    enum Phases { Seeding, Budding, Flowering, Harvest, Handling, Sales, End }
    
    struct Player {
        address playerAddress;
        address upline;
        address[] downlines;
        uint256 downlineProfits;  // TODO: how is these calculated?
    }
    
    // TODO: is the order of user in the list important?
    struct Land {
        uint256 landNumber;
        uint256 phaseStartTime;
        uint256 phaseEndTime;
        uint256 target;
        uint256 funded;
        Phases phase;
        mapping (address => uint256) invested;  // have to use list to track this
        mapping (address => bool) playerExist;
        address[] playersList;    
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
    
    uint256 private initialTotalSeeding = 10000 ether;  // assumet Potato token is 18 decimals
    
    IERC20 private POTATO;
    
    constructor(address _potato) {
        POTATO = IERC20(_potato);
    }
    
    function createLand(uint256 _startTime, uint256[] memory _invested) public {
        uint256 _target;
        // land 2 belum reinvest
        if (landLength == 0) {
            _target = initialTotalSeeding;  
        } else {
            uint256 _previousTarget = lands[landLength-1].target;
            _target = _previousTarget / 100 * 130;
        }
        
        // initialize a land, starts at seeding phase
        Land storage _land = lands[landLength];
        _land.landNumber = landLength;
        _land.phaseStartTime = _startTime;
        _land.phaseEndTime = _startTime + 1 weeks - 1 hours;
        _land.target = _target;
        _land.phase = Phases.Seeding;
        
         // TODO: handle user's reinvestment when land >= 3
         // Clash? Land creation and withdraw decision happening at the same time
         
        
        landLength++;
    }
    
    function proceedToNextPhase(uint256 _landNumber) public {
        Land storage _land = lands[_landNumber];
        
        uint256 _endTime = _land.phaseEndTime;
        
        if (_land.phase == Phases.Seeding) {
            require(block.timestamp >= _endTime + 1 hours, "Not the time yet");
            _land.phaseStartTime = _endTime + 1 hours;
            _land.phaseEndTime = _land.phaseStartTime + 1 weeks;
        } else if (_land.phase == Phases.Budding) {
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = _land.phaseStartTime + 6 hours;
        } else if (_land.phase == Phases.Flowering) {
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = _land.phaseStartTime + 1 days;
        } else if (_land.phase == Phases.Harvest) {
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = _land.phaseStartTime + 1 weeks - 6 hours;
        } else if (_land.phase == Phases.Handling) {
            require(block.timestamp >= _endTime, "Not the time yet");
            _land.phaseStartTime = _endTime;
            _land.phaseEndTime = maxInt;
        } 
        _land.phase = Phases(uint(_land.phase) + 1);
        
    }
    
    function invest(uint256 _landNumber, address _upline, uint256 _amount) public {
        require(_landNumber < landLength, "Not a valid land number");
        require(lands[_landNumber].phase == Phases.Seeding, "This land is not currently in seeding phase");
        require(globalPlayerExist[_upline] || _upline == address(0), "Upline does not exist");
        
        // 0.1% of target
        uint256 _pointOne = lands[_landNumber].target / 1000;
        uint256 _minInvest;
        if (_pointOne < 1000 ether) {
            _minInvest = _pointOne;
        } else {
            _minInvest = 1000 ether;
        }
        uint256 _maxInvest = lands[_landNumber].target * 5 / 100;
        
        Land storage _land = lands[_landNumber];
        uint256 _invested = _land.invested[msg.sender];
        require(_invested + _amount <= _maxInvest, "Seeding amount exceeds maximum");
        require(_invested + _amount >= _minInvest, "Seeding amount is less than minimum");
        require(_land.funded + _amount <= _land.target, "Seeding amount exceeds land target");
        
        uint256 _allowance = POTATO.allowance(msg.sender, address(this));
        require(_allowance >= _amount, "Not enough token allowance");
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
    }
    
    // witdraw decision
    function optOut(uint256 _landNumber) public {
        Land storage _land = lands[_landNumber];
        require(_land.phase == Phases.Flowering, "It is not the flowering phase");
        require(_land.playerExist[msg.sender], "You are not in this land");
        require(!_land.optedOut[msg.sender], "You have already opt out");
        
        // add to opt out list
        _land.optedOut[msg.sender] = true;
        _land.optOutList.push(msg.sender);
        
        // remove from playing list
        uint256 _index = _land.playersIndex[msg.sender];
        address _lastPlayer = _land.playersList[_land.playersList.length - 1];
        _land.playersList[_index] = _lastPlayer;
        _land.playersIndex[msg.sender] = maxInt;
        _land.playersIndex[_lastPlayer] = _index;
        _land.playerExist[msg.sender] = false;
        _land.playersList.pop();
    }
    
    // withdraw at the end of cycle
    function withdraw(uint256 _landNumber) public {
        Land storage _land = lands[_landNumber];
        require(_land.phase == Phases.Sales, "It is not the sales phase");
        require(_land.optedOut[msg.sender], "You are still in the game");
        require(!_land.optOutWithdraw[msg.sender], "You have already withdraw");
        
        uint256 _invested = _land.invested[msg.sender];
        uint256 _withdrawable = _invested / 100 * 115;
        
        _land.optOutWithdraw[msg.sender] = true;
        
        // TODO: need to make sure smart contract has enough balance?
        POTATO.transfer(msg.sender, _withdrawable);
    }
    
    // TODO: handle seeding fail
    
    function withdrawReferral() external {
        
    }
    
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakeEther {
    error AddressZeroDetected();
    error NotOwner();
    error StakingAmountLessThanMinimumStakeAccepted();
    error NoBalanceToUnstake();
    error UnstakingTime();
    error TransferFailed();
    error WithdrawalFailed();

    mapping(address => uint256) public balances;
    mapping(address => uint256) public timeStaked;

    uint256 public minimumStake = 0.001 ether;
    uint256 public rewardRate = 0.00001 ether;
    uint256 public minimumMaturityTime = 1 days;
    uint256 public constant maximumStakeDuration = 30 days;

    address public owner;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    constructor() {
        owner = msg.sender;
    }

    function onlyOwner() private view {
       if(msg.sender != owner) {
            revert NotOwner();
        } 
    }

    function zeroAddressChecker() private view {
        if(msg.sender == address(0)) {
            revert AddressZeroDetected();
        }
    }

    function stakingAmountChecker() private view {
        if(msg.value < minimumStake) {
            revert StakingAmountLessThanMinimumStakeAccepted();
        }
    }

    function balanceChecker() private view {
        if(balances[msg.sender] <= 0) {
            revert NoBalanceToUnstake();
        }
    }

    function unstakingWindowChecker() private view returns(uint256) {
        uint256 _timeStaked = timeStaked[msg.sender];
        uint256 timeElapsed = block.timestamp - _timeStaked;

        if (timeElapsed < minimumMaturityTime) {
            revert UnstakingTime();
        }

        return timeElapsed;
    }

    function transferFunds(bool isSuccessful) private pure {
        if(!isSuccessful) {
            revert TransferFailed(); 
        }
    }

    function withdrawFunds(bool isSuccessful) private pure {
        if(!isSuccessful) {
            revert WithdrawalFailed(); 
        }
    }

    function setMinimumStake(uint256 newMinimumStake) public {
        onlyOwner();
        minimumStake = newMinimumStake;
    }

    function setRewardRate(uint256 newRewardRate) public {
        onlyOwner();
        rewardRate = newRewardRate;
    }

    function stake() public payable {
        zeroAddressChecker();
        stakingAmountChecker();
        stakingAmountChecker();

        balances[msg.sender] += msg.value;
        timeStaked[msg.sender] = block.timestamp;

        emit Staked(msg.sender, msg.value);
    }

    function balanceOf(address user) public view returns (uint256) {
        return balances[user];
    }

    function unstake() public {
        zeroAddressChecker();
        uint256 balance = balances[msg.sender];

        balanceChecker();

        uint256 timeElapsed = unstakingWindowChecker();
        uint256 reward = rewardRate * timeElapsed;

        balances[msg.sender] = 0;
        timeStaked[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: balance + reward}("");
        transferFunds(success);

        emit Unstaked(msg.sender, balance, reward);
    }

    function withdraw() public {
        onlyOwner();

        (bool success, ) = owner.call{value: address(this).balance}("");
        withdrawFunds(success); 
    }

    function withdrawReward() public {
        uint256 balance = balances[msg.sender];
        uint256 _timeStaked = timeStaked[msg.sender];
        uint256 timeElapsed = block.timestamp - _timeStaked;
        uint256 reward = rewardRate * timeElapsed;

        require(reward > 0, "No rewards to withdraw");

        balances[msg.sender] = balance;
        timeStaked[msg.sender] = block.timestamp;

        // payable(msg.sender).transfer(reward);
        (bool success, ) = msg.sender.call{value: reward}("");
        withdrawFunds(success);
    }
}
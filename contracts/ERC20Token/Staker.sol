// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakeERC20 {
    using SafeERC20 for IERC20;

    error AddressZeroDetected();
    error NotOwner();
    error StakingAmountLessThanMinimumStakeAccepted();
    error NoBalanceToUnstake();
    error UnstakingTime();
    error TransferFailed();
    error WithdrawalFailed();

    mapping(address => uint256) public balances;
    mapping(address => uint256) public timeStaked;

    IERC20 public stakingToken;

    uint256 public minimumStake = 0.01 ether;
    uint256 public rewardRate = 1 * 10 ** 16;
    uint256 public minimumMaturityTime = 1 days;
    uint256 public constant maximumStakeDuration = 30 days;

    address public owner;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    function zeroAddressChecker(address user) private pure {
        if (user == address(0)) {
            revert AddressZeroDetected();
        }
    }

    function stakingAmountChecker(uint256 amount) private view {
        if (amount < minimumStake) {
            revert StakingAmountLessThanMinimumStakeAccepted();
        }
    }

    function balanceChecker(address user) private view {
        if (balances[user] <= 0) {
            revert NoBalanceToUnstake();
        }
    }

    function unstakingWindowChecker(address user) private view returns (uint256) {
        uint256 _timeStaked = timeStaked[user];
        uint256 timeElapsed = block.timestamp - _timeStaked;

        if (timeElapsed < minimumMaturityTime) {
            revert UnstakingTime();
        }

        return timeElapsed;
    }

    function transferFunds(bool isSuccessful) private pure {
        if (!isSuccessful) {
            revert TransferFailed();
        }
    }

    function setMinimumStake(uint256 newMinimumStake) public onlyOwner {
        minimumStake = newMinimumStake;
    }

    function setRewardRate(uint256 newRewardRate) public onlyOwner {
        rewardRate = newRewardRate;
    }

    function stake(uint256 amount) public {
        zeroAddressChecker(msg.sender);
        stakingAmountChecker(amount);

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        balances[msg.sender] += amount;
        timeStaked[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function balanceOf(address user) public view returns (uint256) {
        return balances[user];
    }

    function unstake() public {
        zeroAddressChecker(msg.sender);

        uint256 balance = balances[msg.sender];
        balanceChecker(msg.sender);

        uint256 timeElapsed = unstakingWindowChecker(msg.sender);
        uint256 reward = rewardRate * timeElapsed;

        balances[msg.sender] = 0;
        timeStaked[msg.sender] = 0;

        stakingToken.transfer(msg.sender, balance + reward);

        emit Unstaked(msg.sender, balance, reward);
    }

    function withdraw() public onlyOwner {
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        stakingToken.transfer(owner, contractBalance);
    }

    function withdrawReward() public {
        // uint256 balance = balances[msg.sender];
        uint256 _timeStaked = timeStaked[msg.sender];
        uint256 timeElapsed = block.timestamp - _timeStaked;
        uint256 reward = rewardRate * timeElapsed;

        require(reward > 0, "No rewards to withdraw");

        timeStaked[msg.sender] = block.timestamp;

        stakingToken.transfer(msg.sender, reward);
    }
}

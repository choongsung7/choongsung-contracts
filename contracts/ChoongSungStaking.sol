pragma solidity 0.5.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "./interfaces/IChoongSungStaking.sol";

contract ChoongSungStaking is Ownable, IChoongSungStaking {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 staking;
        uint256 rewardDebt;
        uint256 rewardSurplus;
    }

    IERC20 public cs7;

    mapping (address => UserInfo) public userInfo;

    uint256 public totalStaking;

    uint256 public totalReward;

    event Deposit(address indexed user, uint256 amount);

    event Withdraw(address indexed user, uint256 amount);

    event SupplyReward(uint256 amount);

    event ClaimReward(address indexed user, uint256 amount);

    constructor(address _cs7) public {
        cs7 = IERC20(_cs7);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "deposit amount should be positive");

        uint256 amountDept;

        address sender = _msgSender();
        require(sender != address(0), "deposit account should not be zero address");

        UserInfo storage user = userInfo[sender];

        if (totalStaking == 0) {
            amountDept = 0;
        } else {
            amountDept = totalReward.mul(amount).div(totalStaking);
        }

        user.staking = user.staking.add(amount);
        user.rewardDebt = user.rewardDebt.add(amountDept);
        totalStaking = totalStaking.add(amount);
        totalReward = totalReward.add(amountDept);

        cs7.safeTransferFrom(sender, address(this), amount);

        emit Deposit(sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "withdraw amount should be positive");

        uint256 amountSurplus;

        address sender = _msgSender();
        UserInfo storage user = userInfo[sender];
        require(user.staking >= amount, "withdraw amount should be greater than staking");

        if (totalStaking == 0) {
            amountSurplus = 0;
        } else {
            amountSurplus = totalReward.mul(amount).div(totalStaking);
        }

        user.staking = user.staking.sub(amount);
        user.rewardSurplus = user.rewardSurplus.add(amountSurplus);
        totalStaking = totalStaking.sub(amount);
        totalReward = totalReward.sub(amountSurplus);

        cs7.safeTransfer(sender, amount);

        emit Withdraw(sender, amount);
    }

    function claimReward() external {
        address sender = _msgSender();
        UserInfo storage user = userInfo[sender];

        uint256 rewardForStaking;
        uint256 userReward;

        if (totalStaking == 0) {
            rewardForStaking = 0;
        } else {
            rewardForStaking = totalReward.mul(user.staking).div(totalStaking);
        }

        userReward = rewardForStaking.add(user.rewardSurplus).sub(user.rewardDebt);
        require(userReward > 0, "user reward should be positive");

        user.rewardDebt = rewardForStaking;
        user.rewardSurplus = 0;

        cs7.safeTransfer(sender, userReward);

        emit ClaimReward(sender, userReward);
    }

    function supplyReward(uint256 amount) external {
        require(amount > 0, "supplyReward amount should be positive");

        cs7.safeTransferFrom(_msgSender(), address(this), amount);

        totalReward = totalReward.add(amount);

        emit SupplyReward(amount);
    }

    function reward(address user) external view returns (uint256) {
        uint256 userStaking;
        uint256 userRewardDebt;
        uint256 rewardSurplus;
        uint256 userRewardWithoutSurplus;

        userStaking = userInfo[user].staking;
        userRewardDebt = userInfo[user].rewardDebt;
        rewardSurplus = userInfo[user].rewardSurplus;

        if (totalStaking == 0) {
            userRewardWithoutSurplus = 0;
        } else {
            userRewardWithoutSurplus = userStaking.mul(totalReward).div(totalStaking);
        }

        return userRewardWithoutSurplus.add(rewardSurplus).sub(userRewardDebt);
    }
}

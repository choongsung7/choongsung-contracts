pragma solidity 0.5.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

import "./interfaces/IChoongSungPool.sol";
import "./interfaces/IChoongSungStaking.sol";
import "./ChoongSungLPToken.sol";

contract ChoongSungPool is IChoongSungPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'CS7Pool: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    event SwapToCS7(address indexed from, uint256 amount);
    event SwapToKlay(address indexed from, uint256 amount);
    event AddLiquidity(uint256 amountCS7, uint256 amountKlay);
    event RemoveLiquidity(uint256 amountCS7, uint256 amountKlay);

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    event SupplyReward(uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);

    IERC20 public _cs7;
    IChoongSungStaking public _staking;
    ChoongSungLPToken public _lp;

    address public devAddress;

    uint112 private _reserveCS7;
    uint112 private _reserveKLAY;
    uint256 public totalLiquidity;

    uint256 public totalReward;
    mapping(address => uint) public rewardDebtOf;
    mapping(address => uint) public rewardSurplusOf;

    constructor(address cs7, address staking, address lp, address _devAddress) public {
        _cs7 = IERC20(cs7);
        _staking = IChoongSungStaking(staking);
        _lp = ChoongSungLPToken(lp);
        devAddress = _devAddress;
    }

    function getReserves() external view returns (uint112 reserveCS7, uint112 reserveKLAY) {
        reserveCS7 = _reserveCS7;
        reserveKLAY = _reserveKLAY;
    }

    function buyCS7() external payable {
        require(msg.value > 0, 'CS7Pool: INSUFFICIENT_AMOUNT');
        uint256 addedKlay = msg.value;

        uint256 cs7Before = _reserveCS7;
        uint256 klayBefore = _reserveKLAY;
        uint256 newCS7 = addedKlay.mul(cs7Before).div(klayBefore.add(addedKlay));
        require(newCS7 > 0, 'CS7Pool: INSUFFICIENT_SWAP_AMOUNT');

        uint256 fee = newCS7.div(10);

        _distributeFee(fee);
        _cs7.transfer(msg.sender, newCS7.sub(fee));

        // refresh cache variables
        _reserveCS7 = uint112(cs7Before.sub(newCS7));
        _reserveKLAY = uint112(klayBefore.add(addedKlay));

        emit SwapToCS7(msg.sender, addedKlay);
    }

    function sellCS7(uint256 amount) external {
        require(amount > 0, 'CS7Pool: INSUFFICIENT_AMOUNT');

        uint256 fee = amount.div(10);

        uint256 klayBefore = _reserveKLAY;
        uint256 cs7Before = _reserveCS7;
        uint256 newKlay = amount.sub(fee).mul(klayBefore).div(cs7Before.add(amount.sub(fee)));
        require(newKlay > 0, 'CS7Pool: INSUFFICIENT_SWAP_AMOUNT');

        _cs7.transferFrom(msg.sender, address(this), amount);
        msg.sender.transfer(newKlay);

        _distributeFee(fee);

        // refresh cache variables
        _reserveCS7 = uint112(cs7Before.add(amount.sub(fee)));
        _reserveKLAY = uint112(klayBefore.sub(newKlay));

        emit SwapToKlay(msg.sender, amount);
    }

    function addLiquidity(uint256 amountCS7) external payable {
        require(amountCS7 > 0 && msg.value > 0, "CS7Pool: INSUFFICIENT_AMOUNTS");

        // verified amount
        uint256 _amountCS7 = 0;
        uint256 _amountKlay = 0;
        (_amountCS7, _amountKlay) = _addLiquidity(amountCS7, msg.value);
        uint256 totalLiquidityBefore = totalLiquidity;

        // if verified klay amount was less than paid klay, refund diff
        (bool result, uint256 diff) = trySub(_amountKlay, msg.value);
        if (diff > 0) {
            msg.sender.transfer(diff);
        }

        _cs7.transferFrom(msg.sender, address(this), _amountCS7);

        uint liquidity = mint(msg.sender);

        // calculate debt and record it
        uint256 amountDept;
        if (totalLiquidityBefore == 0) {
            amountDept = 0;
        } else {
            amountDept = totalReward.mul(liquidity).div(totalLiquidityBefore);
        }
        rewardDebtOf[msg.sender] = rewardDebtOf[msg.sender].add(amountDept);
        totalReward = totalReward.add(amountDept);
    }

    function removeLiquidity(uint liquidity) external {
        address payable user = msg.sender;
        require(liquidity > 0, "CS7Pool: INVALID_LIQUIDITY_TO_BURN");
        require(_lp.balanceOf(user) >= liquidity, "CS7Pool: INSUFFICIENT_LIQUIDITY_TO_BURN");

        // calculate surplus and record it
        uint256 amountSurplus;
        if (totalLiquidity == 0) {
            amountSurplus = 0;
        } else {
            amountSurplus = totalReward.mul(liquidity).div(totalLiquidity);
        }
        rewardSurplusOf[user] = rewardSurplusOf[user].add(amountSurplus);
        totalReward = totalReward.sub(amountSurplus);

        _lp.transferFrom(msg.sender, address(this), liquidity);
        burn(liquidity, user);
    }

    function _addLiquidity(uint256 amountCS7Desired, uint256 amountKlayDesired) internal view returns (uint256 amountA, uint256 amountB) {
        // empty pool
        // set added liquidity
        if (_reserveCS7 == 0 && _reserveKLAY == 0) {
            return (amountCS7Desired, amountKlayDesired);
        }

        // 1. if amountKlayDesired is greater than or equal to klay min amount
        uint klayMinAmount = _quote(amountCS7Desired, _reserveCS7, _reserveKLAY);
        if (klayMinAmount <= amountKlayDesired) {
            return (amountCS7Desired, klayMinAmount);
        }

        // 2. if amountKlayDesired is less than needed klay min amount
        uint cs7MinAmount = _quote(amountKlayDesired, _reserveKLAY, _reserveCS7);
        require(amountCS7Desired >= cs7MinAmount, 'CS7Pool: INSUFFICIENT_CS7_AMOUNT');
        return (cs7MinAmount, amountKlayDesired);
    }

    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, 'CS7Pool: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'CS7Pool: INSUFFICIENT_LIQUIDITY');

        amountB = amountA.mul(reserveB).div(reserveA);
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balanceCS7, uint balanceKLAY) private {
        // using underflow, to get max value of uint112
        require(balanceCS7 <= uint112(- 1) && balanceKLAY <= uint112(- 1), 'CS7Pool: OVERFLOW');

        _reserveCS7 = uint112(balanceCS7);
        _reserveKLAY = uint112(balanceKLAY);

        emit Sync(_reserveCS7, _reserveKLAY);
    }

    // calculate LP token amount, give it to sender
    function mint(address to) internal lock returns (uint liquidity) {
        // gas savings
        uint balanceCS7 = _cs7.balanceOf(address(this));
        uint balanceKLAY = address(this).balance;
        uint amountCS7 = balanceCS7.sub(_reserveCS7);
        uint amountKLAY = balanceKLAY.sub(_reserveKLAY);

        if (totalLiquidity == 0) {
            liquidity = sqrt(amountCS7.mul(amountKLAY));
            uint256 verified = Math.min(liquidity, MINIMUM_LIQUIDITY);
            liquidity = liquidity.sub(verified);
            _lp.mint(address(0), MINIMUM_LIQUIDITY);
            // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amountCS7.mul(totalLiquidity).div(_reserveCS7), amountKLAY.mul(totalLiquidity).div(_reserveKLAY));
        }
        require(liquidity > 0, 'CS7Pool: INSUFFICIENT_LIQUIDITY_MINTED');

        _lp.mint(to, liquidity);
        totalLiquidity = totalLiquidity.add(liquidity);
        _update(balanceCS7, balanceKLAY);

        // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amountCS7, amountKLAY);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(uint liquidityToBurn, address payable to) internal lock returns (uint amountCS7, uint amountKLAY) {
        uint balanceCS7 = _cs7.balanceOf(address(this));
        uint balanceKLAY = address(this).balance;
        uint liquidity = _lp.balanceOf(address(this));

        amountCS7 = balanceCS7.mul(liquidity).div(totalLiquidity);
        amountKLAY = balanceKLAY.mul(liquidity).div(totalLiquidity);
        require(amountCS7 > 0 && amountKLAY > 0, 'CS7Pool: INSUFFICIENT_LIQUIDITY_BURNED');

        _lp.burn(address(this), liquidityToBurn);
        totalLiquidity = totalLiquidity.sub(liquidityToBurn);

        _cs7.transfer(to, amountCS7);
        to.transfer(amountKLAY);

        balanceCS7 = _cs7.balanceOf(address(this));
        balanceKLAY = address(this).balance;

        _update(balanceCS7, balanceKLAY);

        emit Burn(msg.sender, amountCS7, amountKLAY, to);
    }

    function supplyLiquidityReward(uint256 amount) internal {
        require(amount > 0, "supplyReward amount should be positive");

        totalReward = totalReward.add(amount);

        emit SupplyReward(amount);
    }

    function liquidity(address account) external view returns (uint256, uint256) {
        if (totalLiquidity == 0) {
            return (0, 0);
        }

        uint256 liquidityOwned = _lp.balanceOf(account);
        uint256 amountCS7 = uint256(_reserveCS7).mul(liquidityOwned).div(totalLiquidity);
        uint256 amountKLAY = uint256(_reserveKLAY).mul(liquidityOwned).div(totalLiquidity);

        return (amountCS7, amountKLAY);
    }

    function reward(address account) external view returns (uint256) {
        if (totalLiquidity == 0) {
            return 0;
        }
        if (totalReward == 0) {
            return 0;
        }

        uint256 userLiquidity = _lp.balanceOf(account);
        if (userLiquidity == 0) {
            return 0;
        }

        uint256 userRewardSurplus = rewardSurplusOf[account];
        uint256 userRewardDebt = rewardDebtOf[account];
        return userLiquidity.mul(totalReward).div(totalLiquidity).add(userRewardSurplus).sub(userRewardDebt);
    }

    function claimReward() external {
        address sender = msg.sender;

        // calculate user reward
        uint256 rewardForLiquidity;
        uint256 userLiquidity = _lp.balanceOf(sender);
        if (totalLiquidity == 0) {
            rewardForLiquidity = 0;
        } else {
            rewardForLiquidity = totalReward.mul(userLiquidity).div(totalLiquidity);
        }
        uint256 userRewardSurplus = rewardSurplusOf[sender];
        uint256 userRewardDebt = rewardDebtOf[sender];
        uint256 userReward = rewardForLiquidity.add(userRewardSurplus).sub(userRewardDebt);

        require(userReward > 0, "user reward should be positive");
        rewardDebtOf[sender] = rewardForLiquidity;
        rewardSurplusOf[sender] = 0;
        _cs7.safeTransfer(sender, userReward);

        emit ClaimReward(sender, userReward);
    }

    function _distributeFee(uint256 fee) internal {
        uint256 stakingHoldersFee;
        uint256 lpProviderFee;
        uint256 devFee;

        // 6% for Staking (60% of fee)
        stakingHoldersFee = fee.mul(6).div(10);
        if (stakingHoldersFee > 0) {
            _cs7.approve(address(_staking), stakingHoldersFee);
            _staking.supplyReward(stakingHoldersFee);
        }

        // 3% for Liquidity (30% of fee)
        lpProviderFee = fee.mul(3).div(10);
        if (lpProviderFee > 0) {
            supplyLiquidityReward(lpProviderFee);
        }

        // 1% for CS7 (10% of fee)
        devFee = fee.sub(stakingHoldersFee).sub(lpProviderFee);
        if (devFee > 0) {
            _cs7.safeTransfer(devAddress, devFee);
        }
    }

    function dev(address _devAddress) public {
        require(msg.sender == devAddress);
        devAddress = _devAddress;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }
}

pragma solidity 0.5.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

import "./interfaces/IChoongSungPool.sol";
import "./interfaces/IChoongSungStaking.sol";
import "./ChoongSungPoolERC20.sol";

// TODO: 야근
contract ChoongSungPool is IChoongSungPool, ChoongSungPoolERC20, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

    event SwapToCS7(address indexed from, uint256 amount);
    event SwapToKlay(address indexed from, uint256 amount);
    event AddLiquidity(uint256 amountCS7, uint256 amountKlay);
    event RemoveLiquidity(uint256 amountCS7, uint256 amountKlay);

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1); // use this event to sync chart

    event SupplyReward(uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);

    IERC20 public _cs7;
    IChoongSungStaking public _staking;
    address public devAddress;

    uint112 private _reserveCS7;
    uint112 private _reserveKLAY;

    uint256 public totalReward;

    mapping(address => uint) public rewardDebtOf;
    mapping(address => uint) public rewardSurplusOf;

    constructor(address cs7, address staking, address _devAddress) public {
        _cs7 = IERC20(cs7);
        _staking = IChoongSungStaking(staking);
        devAddress = _devAddress;
    }

    function getReserves() external view returns (uint112 reserveCS7, uint112 reserveKLAY) {
        reserveCS7 = _reserveCS7;
        reserveKLAY = _reserveKLAY;
    }

    function buyCS7() external payable {
    }

    function sellCS7(uint256 amount) external {
    }

    function addLiquidity(uint256 amountCS7) external payable {
    }

    function removeLiquidity(uint liquidity) external {
    }

    function liquidity(address account) external view returns (uint256, uint256) {
        return (0, 0);
    }

    function reward(address account) external view returns (uint256) {
        return 0;
    }

    function claimReward() external {
    }
}

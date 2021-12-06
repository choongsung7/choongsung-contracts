pragma solidity 0.5.6;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

contract ChoongSungLPToken is Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event SupplyReward(uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);

    string public constant name = 'ChoongSung LP Token';

    string public constant symbol = 'CS7LP';

    uint8 public constant decimals = 18;

    uint256 public totalLiquidity;

    address public poolAddress;

    mapping(address => uint) public balanceOf;

    mapping(address => mapping(address => uint)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint value);

    event Transfer(address indexed from, address indexed to, uint value);

    constructor() public {
        poolAddress = msg.sender;
    }

    function approve(address spender, uint value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) public returns (bool) {
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function mint(address to, uint value) external {
        require(msg.sender == poolAddress);

        totalLiquidity = totalLiquidity.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function burn(address from, uint value) external {
        require(msg.sender == poolAddress);

        balanceOf[from] = balanceOf[from].sub(value);
        totalLiquidity = totalLiquidity.sub(value);
        emit Transfer(from, address(0), value);
    }

    function updatePoolAddress(address _poolAddress) external onlyOwner {
        poolAddress = _poolAddress;
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private whenNotPaused {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }
}

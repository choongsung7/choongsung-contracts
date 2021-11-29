pragma solidity 0.5.6;

interface IChoongSungPool {
    function buyCS7() external payable;

    function sellCS7(uint256 amount) external;

    function addLiquidity(uint256 amountCS7) external payable;

    function removeLiquidity(uint256 liquidity) external;

    function getReserves() external view returns (uint112, uint112);

    function liquidity(address account) external view returns (uint256, uint256);

    function reward(address account) external view returns (uint256);

    function claimReward() external;
}

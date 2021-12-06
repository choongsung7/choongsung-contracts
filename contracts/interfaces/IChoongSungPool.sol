pragma solidity 0.5.6;

interface IChoongSungPool {
    function buyCS7() external payable;

    function sellCS7(uint256 amount) external;

    function addLiquidity(uint256 amountCS7) external payable;

    function removeLiquidity(uint256 liquidity) external;

    function getReserves() external view returns (uint112, uint112);

    // account 의 liquidity 공급량을 확인 합니다.
    function liquidity(address account) external view returns (uint256, uint256);

    // account 의 reward 를 확인 합니다.
    function reward(address account) external view returns (uint256);

    // msg.sender 에게 받아야 할 보상을 제공 합니다.
    function claimReward() external;
}

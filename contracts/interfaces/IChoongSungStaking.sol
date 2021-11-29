pragma solidity 0.5.6;

interface IChoongSungStaking {
    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function claimReward() external;

    function supplyReward(uint256 amount) external;

    function reward(address user) external view returns (uint256);
}

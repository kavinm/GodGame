
pragma solidity ^0.8.0;

interface ITemple {
    function addManyToTempleAndPantheon(address account, uint16[] calldata tokenIds)
        external;

    function randomGodOwner(uint256 seed) external view returns (address);
}

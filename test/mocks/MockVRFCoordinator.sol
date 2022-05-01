//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract MockVRFCoordinator {
    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external returns (uint256 requestId) {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(
            keccak256(abi.encode(msg.sender, block.timestamp))
        );
        VRFConsumerBaseV2(msg.sender).rawFulfillRandomWords(
            requestId,
            randomWords
        );
    }
}

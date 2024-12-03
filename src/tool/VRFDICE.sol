// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract VRFDICE is VRFConsumerBaseV2Plus {
    uint256 private constant ROLL_IN_PROGRESS = 42;

    uint256 private s_playerLength;
    uint256 private immutable i_subscriptionId;
    address private immutable i_vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 private immutable i_keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 private immutable i_callbackGasLimit = 40000;
    uint16 private immutable i_requestConfirmations = 3;
    uint32 private immutable i_numWords = 1;

    mapping(uint256 => address) private s_rollers;
    mapping(address => uint256) private s_results;

    event DiceRolled(uint256 indexed requestId, address indexed roller);

    constructor(uint256 subscriptionId) VRFConsumerBaseV2Plus(i_vrfCoordinator) {
        i_subscriptionId = subscriptionId;
    }

    function rollDice(
        address roller
    ) public onlyOwner returns (uint256 requestId) {
        require(s_results[roller] == 0, "Already rolled");
        // Will revert if subscription is not set and funded.

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: i_requestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: i_numWords,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        s_rollers[requestId] = roller;
        s_results[roller] = ROLL_IN_PROGRESS;
        emit DiceRolled(requestId, roller);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {

    }
}

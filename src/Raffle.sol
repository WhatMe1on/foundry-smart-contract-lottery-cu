// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {Script, console} from "forge-std/Script.sol";

contract Raffle is VRFConsumerBaseV2Plus,Script{
    error Raffle__NotEnoughEtherSent();
    error Raffle__WinnerWithdrawFailed();
    error Raffle__RaffleStateNotOpen();
    error Raffle__UpKeepNotFeed(
        bytes upKeepFlags,
        uint256 balance,
        uint256 length
    );

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private constant ROLL_IN_PROGRESS = 42;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    address private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    address payable s_recentWinner;
    uint256 private s_lastTimestamp;
    RaffleState private s_raffleState;

    event EnterRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        uint256 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_lastTimestamp = block.timestamp;
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        s_raffleState = RaffleState.OPEN;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_vrfCoordinator = vrfCoordinator;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEtherSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleStateNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnterRaffle(msg.sender);
    }

    /**
     * @dev Function is to check
     * 1.Time has passed
     * 2.Raffle state is open
     * 3.Contract has eth
     * 4.Subscription is funded with Link
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = block.timestamp - s_lastTimestamp >= i_interval;
        bool stateIsOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayer = s_players.length > 0;
        // console.log(timeHasPassed);
        // console.log(stateIsOpen);
        // console.log(hasBalance);
        // console.log(hasPlayer);
        upkeepNeeded = timeHasPassed && stateIsOpen && hasBalance && hasPlayer;
        //TODO if output false ,use event to replace the upKeepFlags, And compare the gas spent
        bytes memory upKeepFlags = abi.encode(timeHasPassed,stateIsOpen,hasBalance,hasPlayer);
        return (upkeepNeeded, upKeepFlags);
    }

    function performUpKeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, bytes memory upKeepFlags) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotFeed(
                upKeepFlags,
                address(this).balance,
                s_players.length
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        s_recentWinner = s_players[indexOfWinner];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__WinnerWithdrawFailed();
        }
    }

    /**Getter Function */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getIndexedPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }
}

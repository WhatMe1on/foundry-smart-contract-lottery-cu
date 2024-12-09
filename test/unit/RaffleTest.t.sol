// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {CCEncoder} from "../../src/tools/CCEncoder.sol";
import {Vm} from "forge-std/Vm.sol";
import {CCEncoder} from "~homesrc/tools/CCEncoder.sol";

contract RaffleTest is Test {
    using CCEncoder for bool[];
    using CCEncoder for bool[4];
    event EnterRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;

    address public PlayerAddress = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /* Modifiers */
    modifier M_prankPlayer() {
        vm.startPrank(PlayerAddress);
        _;
        vm.stopPrank();
    }

    modifier M_enterRaffle() {
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    modifier M_timePassed() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /* Functions */
    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        vm.deal(PlayerAddress, STARTING_USER_BALANCE);
        (entranceFee, interval, , , , , ) = helperConfig.activeNetworkConfig();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouPayNotEnough() public {
        vm.prank(PlayerAddress);
        vm.expectRevert(Raffle.Raffle__NotEnoughEtherSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter()
        public
        M_prankPlayer
        M_enterRaffle
    {
        address addressFromRaffle = raffle.getIndexedPlayer(0);
        assertEq(addressFromRaffle, PlayerAddress);
    }

    function testEmitsEventOnEntrance() public M_prankPlayer M_enterRaffle {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnterRaffle(PlayerAddress);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating()
        public
        M_prankPlayer
        M_enterRaffle
        M_timePassed
    {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleStateNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance()
        public
        M_prankPlayer
        M_timePassed
    {
        // raffle.enterRaffle();

        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen()
        public
        M_prankPlayer
        M_enterRaffle
        M_timePassed
    {
        raffle.performUpkeep("");

        (bool upkeepFlag, ) = raffle.checkUpkeep("");
        assert(!upkeepFlag);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed()
        public
        M_prankPlayer
        M_enterRaffle
    {
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        bool[4] memory inputflags = [false, true, true, true];
        bytes memory upKeepFlags = inputflags.castFlags();

        (, bytes memory flags) = raffle.checkUpkeep("");

        assertEq(upKeepFlags, flags);
    }

    function testCheckUpkeepReturnsFalseIfStateNotOpen()
        public
        M_prankPlayer
        M_enterRaffle
        M_timePassed
    {
        bool[4] memory inputflags = [true, false, true, true];
        bytes memory upKeepFlags = inputflags.castFlags();
        raffle.performUpkeep("");

        (, bytes memory flags) = raffle.checkUpkeep("");

        assertEq(upKeepFlags, flags);
    }

    function testCheckUpkeepReturnsFalseIfBalanceZero()
        public
        M_prankPlayer
        M_enterRaffle
        M_timePassed
    {
        vm.deal(address(raffle), 0);
        bool[4] memory inputflags = [true, true, false, true];

        bytes memory upKeepFlags = inputflags.castFlags();

        (, bytes memory flags) = raffle.checkUpkeep("");

        assertEq(upKeepFlags, flags);
    }

    function testCheckUpkeepReturnsFalseIfNoPlayer()
        public
        M_prankPlayer
        M_timePassed
    {
        vm.deal(address(raffle), 1 ether);
        bool[4] memory inputflags = [true, true, true, false];
        bytes memory upKeepFlags = inputflags.castFlags();

        (, bytes memory flags) = raffle.checkUpkeep("");

        assertEq(upKeepFlags, flags);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood()
        public
        M_prankPlayer
        M_enterRaffle
        M_timePassed
    {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        M_prankPlayer
        M_enterRaffle
        M_timePassed
    {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse()
        public
        M_prankPlayer
        M_enterRaffle
    {
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        bool[4] memory inputflags = [false, true, true, true];
        bytes memory upKeepFlags = inputflags.castFlags();

        bytes memory expectedRevertData = abi.encodeWithSelector(
            Raffle.Raffle__UpKeepNotFeed.selector,
            upKeepFlags,
            address(raffle).balance,
            1
        );
        vm.expectRevert(expectedRevertData);
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitsRequestId()
        public
        M_enterRaffle
        M_enterRaffle
        M_timePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // console.log(uint256(raffleState));
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }
}

contract ToolTest is Test {
    using CCEncoder for bool;
    using CCEncoder for bool[];

    function testCastSingleTrueFlag() public pure {
        bool trueFlag = true;
        assertEq(trueFlag.castFlag(), bytes("1"));
    }

    function testCastSingleFalseFlag() public pure {
        bool falseFlag = false;
        assertEq(falseFlag.castFlag(), bytes("0"));
    }

    function testCastMultiFlag() public pure {
        bool[] memory flags = new bool[](4);
        flags[0] = true;
        flags[1] = false;
        flags[2] = false;
        flags[3] = false;

        assertEq(
            flags.castFlags(),
            bytes.concat(bytes("1"), bytes("0"), bytes("0"), bytes("0"))
        );
    }
}

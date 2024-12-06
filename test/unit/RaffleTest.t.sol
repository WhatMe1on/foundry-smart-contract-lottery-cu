// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";

contract RaffleTest is Test {
    event EnterRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;

    address public PlayerAddress = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

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

    function testCantEnterWhenRaffleIsCalculating() public M_prankPlayer {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        vm.expectRevert(Raffle.Raffle__RaffleStateNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance()
        public
        M_prankPlayer
    {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // raffle.enterRaffle();

        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public M_prankPlayer {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        (bool upkeepFlag, ) = raffle.checkUpkeep("");
        assert(!upkeepFlag);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed()
        public
        M_prankPlayer
    {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        bytes memory upKeepFlags = abi.encode(false, true, true, true);

        (, bytes memory flags) = raffle.checkUpkeep("");

        assertEq(upKeepFlags, flags);
    }

    function testCheckUpkeepReturnsFalseIfStateNotOpen()
        public
        M_prankPlayer
    {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        bytes memory upKeepFlags = abi.encode(true, false, true, true);
        raffle.performUpKeep("");

        (, bytes memory flags) = raffle.checkUpkeep("");

        assertEq(upKeepFlags, flags);
    }

    function testCheckUpkeepReturnsFalseIfBalanceZero()
        public
        M_prankPlayer
    {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.deal(address(raffle), 0);
        bytes memory upKeepFlags = abi.encode(true, true, false, true);

        (, bytes memory flags) = raffle.checkUpkeep("");

        assertEq(upKeepFlags, flags);
    }

    function testCheckUpkeepReturnsFalseIfNoPlayer()
        public
        M_prankPlayer
    {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.deal(address(raffle), 1 ether);
        bytes memory upKeepFlags = abi.encode(true, true, true, false);

        (, bytes memory flags) = raffle.checkUpkeep("");
        
        assertEq(upKeepFlags, flags);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood()
        public
        M_prankPlayer
    {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        M_prankPlayer
    {        
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse()
        public
        M_prankPlayer
    {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        //TODO encode msg can be shorter like "0,1,1,1", maybe can implement a custom Encoder
        bytes memory upKeepFlags = abi.encode(false, true, true, true);

        bytes memory expectedRevertData = abi.encodeWithSelector(
            Raffle.Raffle__UpKeepNotFeed.selector,
            upKeepFlags,
            address(raffle).balance,
            1
        );
        vm.expectRevert(expectedRevertData);
        raffle.performUpKeep("");
    }

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
}

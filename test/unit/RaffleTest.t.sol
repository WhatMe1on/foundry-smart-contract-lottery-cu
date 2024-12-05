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
        (entranceFee, interval, , , , ) = helperConfig.activeNetworkConfig();
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
        M_PrankPlayer
        M_EnterRaffle
    {
        address addressFromRaffle = raffle.getIndexedPlayer(0);
        assertEq(addressFromRaffle, PlayerAddress);
    }

    function testEmitsEventOnEntrance() public M_PrankPlayer M_EnterRaffle {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnterRaffle(PlayerAddress);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public M_PrankPlayer {
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        vm.expectRevert(Raffle.Raffle__UpKeepNotFeed.selector);
        raffle.enterRaffle{value: entranceFee}();
    }
    
    /* Modifiers */
    modifier M_PrankPlayer() {
        vm.startPrank(PlayerAddress);
        _;
        vm.stopPrank();
    }

    modifier M_EnterRaffle() {
        raffle.enterRaffle{value: entranceFee}();
        _;
    }
}

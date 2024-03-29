// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./mocks/CheatCodes.sol";
import "./mocks/MockERC721.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockVRFCoordinator.sol";
import "../src/RaffleBurn.sol";
import "forge-std/console.sol";

abstract contract RaffleBurnHelper is CheatCodesDSTest {
    MockVRFCoordinator vrfCoordinator = new MockVRFCoordinator();

    RaffleBurn rb;

    MockERC721 nft1;
    MockERC721 nft2;
    MockERC721 nft3;

    MockERC20 t1;
    MockERC20 t2;
    MockERC20 t3;

    uint256 constant PRICE = 100e18;
    uint256 constant DURATION = 100;
    uint256 constant MAX_ALLOWANCE = 2**256 - 1;

    uint256 constant NFT1_MINTS = 3;
    uint256 constant NFT2_MINTS = 100;
    uint256 constant NFT3_MINTS = 0;
    uint256 constant T1_ISSUANCE = PRICE * type(uint96).max;
    uint256 constant T2_ISSUANCE = PRICE * 10;
    uint256 constant T3_ISSUANCE = 0;

    address a1 = 0x0000000000000000000000000000000000000001;
    address a2 = 0x0000000000000000000000000000000000000002;
    address a3 = 0x0000000000000000000000000000000000000003;
    address dead = address(0xdead);

    function setUp() public virtual {
        rb = new RaffleBurn(address(vrfCoordinator));
        nft1 = new MockERC721();
        nft2 = new MockERC721();
        nft3 = new MockERC721();
        t1 = new MockERC20();
        t2 = new MockERC20();
        t3 = new MockERC20();
        mintTokens();
    }

    function mintTokens() public {
        nft1.mint(address(this), NFT1_MINTS);
        nft1.mint(a1, NFT1_MINTS);
        nft1.mint(a2, NFT1_MINTS);
        nft1.mint(a3, NFT1_MINTS);
        nft2.mint(address(this), NFT2_MINTS);
        nft2.mint(a1, NFT2_MINTS);
        nft2.mint(a2, NFT2_MINTS);
        nft2.mint(a3, NFT2_MINTS);
        nft3.mint(address(this), NFT3_MINTS);
        nft3.mint(a1, NFT3_MINTS);
        nft3.mint(a2, NFT3_MINTS);
        nft3.mint(a3, NFT3_MINTS);
        t1.mint(address(this), T1_ISSUANCE);
        t1.mint(a1, T1_ISSUANCE);
        t1.mint(a2, T1_ISSUANCE);
        t1.mint(a3, T1_ISSUANCE);
        t2.mint(address(this), T2_ISSUANCE);
        t2.mint(a1, T2_ISSUANCE);
        t2.mint(a2, T2_ISSUANCE);
        t2.mint(a3, T2_ISSUANCE);
        t3.mint(address(this), T3_ISSUANCE);
        t3.mint(a1, T3_ISSUANCE);
        t3.mint(a2, T3_ISSUANCE);
        t3.mint(a3, T3_ISSUANCE);
    }

    function createDummyRaffle(address prizeToken, address paymentToken)
        public
        returns (uint256 raffleId)
    {
        MockERC721(prizeToken).setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 0));
        raffleId = rb.createRaffle(
            prizeToken,
            tokenIds,
            paymentToken,
            false,
            uint40(block.timestamp),
            uint40(block.timestamp + DURATION),
            uint160(PRICE)
        );
    }
}

contract CreateRaffleTest is RaffleBurnHelper {
    function testCreateRaffle() public {
        nft1.setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](2);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        tokenIds[1] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        uint256 raffleId = rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t1),
            false,
            uint40(block.timestamp),
            uint40(block.timestamp + 100),
            100e18
        );

        // check raffleId
        assertEq(raffleId, 0);

        // check raffle data
        (
            address paymentToken,
            bool burnable,
            uint40 startTimestamp,
            uint40 endTimestamp,
            uint160 ticketPrice,
            uint96 seed
        ) = rb.raffles(raffleId);
        assertEq(paymentToken, address(t1));
        assertTrue(!burnable);
        assertEq(seed, 0);
        assertEq(startTimestamp, uint40(block.timestamp));
        assertEq(endTimestamp, uint40(block.timestamp + 100));
        assertEq(ticketPrice, 100e18);

        for (uint96 i = 0; i < tokenIds.length; i++) {
            // prize token should be owned by contract
            assertEq(nft1.ownerOf(tokenIds[i]), address(rb));

            // check prize data
            (
                address tokenAddress,
                uint96 tokenId,
                address owner,
                bool claimed
            ) = rb.rafflePrizes(raffleId, i);
            assertEq(tokenAddress, address(nft1));
            assertEq(tokenId, tokenIds[i]);
            assertEq(owner, address(this));
            assertTrue(!claimed);
        }
    }

    function testRaffleIdIncrement() public {
        uint256 raffleId1 = createDummyRaffle(address(nft1), address(t1));
        uint256 raffleId2 = createDummyRaffle(address(nft2), address(t1));
        uint256 raffleId3 = createDummyRaffle(address(nft1), address(t1));
        assertEq(raffleId1, 0);
        assertEq(raffleId2, 1);
        assertEq(raffleId3, 2);
    }

    function testPrizeNotApproved() public {
        uint96[] memory tokenIds = new uint96[](2);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        tokenIds[1] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        cheats.expectRevert(
            bytes("ERC721: transfer caller is not owner nor approved")
        );
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t1),
            false,
            uint40(block.timestamp),
            uint40(block.timestamp + 100),
            100e18
        );
    }

    function testInvalidPrizeToken() public {
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 0));
        cheats.expectRevert(bytes("prizeToken cannot be null"));
        rb.createRaffle(
            address(0),
            tokenIds,
            address(t2),
            false,
            uint40(0),
            uint40(block.timestamp),
            100e18
        );
    }

    function testInvalidPaymentToken() public {
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        cheats.expectRevert(bytes("paymentToken cannot be null"));
        rb.createRaffle(
            address(nft3),
            tokenIds,
            address(0),
            false,
            uint40(0),
            uint40(block.timestamp),
            100e18
        );
    }

    function testInvalidEndTimestamp() public {
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        cheats.expectRevert(bytes("endTimestamp must be in the future"));
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t3),
            false,
            uint40(block.timestamp),
            uint40(block.timestamp),
            100e18
        );
    }

    function testInvalidTicketPrice() public {
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        cheats.expectRevert(bytes("ticketPrice must be greater than 0"));
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t3),
            false,
            uint40(block.timestamp),
            uint40(block.timestamp + DURATION),
            0
        );
    }

    function testInvalidTokenIds() public {
        nft1.setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](3);
        // create with token not owned by creator
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        tokenIds[1] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        tokenIds[2] = uint96(nft1.tokenOfOwnerByIndex(a1, 2));
        cheats.expectRevert(
            bytes("ERC721: transfer caller is not owner nor approved")
        );
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t3),
            false,
            uint40(block.timestamp),
            uint40(block.timestamp + DURATION),
            1e18
        );

        // create with duplicate tokens
        tokenIds[2] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        cheats.expectRevert(bytes("ERC721: transfer from incorrect owner"));
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t3),
            false,
            uint40(block.timestamp),
            uint40(block.timestamp + DURATION),
            1e18
        );
    }
}

contract AddPrizesTest is RaffleBurnHelper {
    function testAddPrizes() public {
        cheats.startPrank(a1);
        uint96[] memory tokenIds = new uint96[](2);
        tokenIds[0] = uint96(nft2.tokenOfOwnerByIndex(a1, 2));
        tokenIds[1] = uint96(nft2.tokenOfOwnerByIndex(a1, 0));
        nft2.setApprovalForAll(address(rb), true);
        rb.addPrizes(123, address(nft2), tokenIds);

        for (uint96 i = 0; i < tokenIds.length; i++) {
            // prize token should be owned by contract
            assertEq(nft2.ownerOf(tokenIds[i]), address(rb));

            // check prize data
            (
                address tokenAddress,
                uint96 tokenId,
                address owner,
                bool claimed
            ) = rb.rafflePrizes(123, i);
            assertEq(tokenAddress, address(nft2));
            assertEq(tokenId, tokenIds[i]);
            assertEq(owner, a1);
            assertTrue(!claimed);
        }
    }

    function testEmptyTokenIds() public {
        uint96[] memory tokenIds = new uint96[](0);
        cheats.expectRevert(bytes("tokenIds must be non-empty"));
        rb.addPrizes(0, address(nft2), tokenIds);
    }

    function testInvalidTokenIds() public {
        cheats.startPrank(a3);
        nft2.setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](3);
        // create with token not owned by creator
        tokenIds[0] = uint96(nft2.tokenOfOwnerByIndex(a3, 2));
        tokenIds[1] = uint96(nft2.tokenOfOwnerByIndex(a3, 1));
        tokenIds[2] = uint96(nft2.tokenOfOwnerByIndex(a2, 0));
        cheats.expectRevert(
            bytes("ERC721: transfer caller is not owner nor approved")
        );
        rb.addPrizes(42, address(nft2), tokenIds);

        // create with duplicate tokens
        tokenIds[2] = uint96(nft2.tokenOfOwnerByIndex(a3, 1));
        cheats.expectRevert(bytes("ERC721: transfer from incorrect owner"));
        rb.addPrizes(42, address(nft2), tokenIds);
    }

    function testInvalidRepeatAddPrizes() public {
        cheats.startPrank(a1);
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft2.tokenOfOwnerByIndex(a1, 0));
        nft2.setApprovalForAll(address(rb), true);
        rb.addPrizes(123, address(nft2), tokenIds);
        cheats.expectRevert(bytes("ERC721: transfer from incorrect owner"));
        rb.addPrizes(123, address(nft2), tokenIds);
    }
}

contract BuyTicketsTest is RaffleBurnHelper {
    function testBuyTickets(uint256 allowance, uint96 ticketCount) public {
        cheats.assume(allowance >= ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), allowance);
        uint256 balanceBefore = t1.balanceOf(address(this));
        rb.buyTickets(raffleId, ticketCount);
        uint256 balanceAfter = t1.balanceOf(address(this));
        assertEq(balanceBefore - balanceAfter, PRICE * ticketCount);
        assertEq(t1.balanceOf(dead), PRICE * ticketCount);
    }

    function testBuyTicketsBurnable(uint256 allowance, uint96 ticketCount)
        public
    {
        cheats.assume(allowance >= ticketCount * PRICE);
        address prizeToken = address(nft1);
        address paymentToken = address(t1);
        MockERC721(prizeToken).setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 0));
        uint256 raffleId = rb.createRaffle(
            prizeToken,
            tokenIds,
            paymentToken,
            true,
            uint40(block.timestamp),
            uint40(block.timestamp + DURATION),
            uint160(PRICE)
        );
        t1.approve(address(rb), allowance);
        uint256 balanceBefore = t1.balanceOf(address(this));
        uint256 totalSupplyBefore = t1.totalSupply();
        rb.buyTickets(raffleId, ticketCount);
        uint256 balanceAfter = t1.balanceOf(address(this));
        uint256 totalSupplyAfter = t1.totalSupply();
        assertEq(balanceBefore - balanceAfter, PRICE * ticketCount);
        assertEq(totalSupplyBefore - totalSupplyAfter, PRICE * ticketCount);
    }

    function testCannotBuyTicketsAllowance(
        uint256 allowance,
        uint96 ticketCount
    ) public {
        cheats.assume(allowance < ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), allowance);
        cheats.expectRevert(bytes("ERC20: insufficient allowance"));
        rb.buyTickets(raffleId, ticketCount);
    }

    function testCannotBuyTicketsIssuance(uint96 ticketCount) public {
        // spend more than the issuance
        cheats.assume(T2_ISSUANCE < ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(address(nft1), address(t2));
        t2.approve(address(rb), MAX_ALLOWANCE);
        cheats.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        rb.buyTickets(raffleId, ticketCount);
    }

    function testCannotBuyTicketsBeforeStart() public {
        address prizeToken = address(nft1);
        address paymentToken = address(t1);
        MockERC721(prizeToken).setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 0));
        uint256 raffleId = rb.createRaffle(
            prizeToken,
            tokenIds,
            paymentToken,
            false,
            uint40(block.timestamp + 1),
            uint40(block.timestamp + DURATION),
            uint160(PRICE)
        );

        t1.approve(address(rb), MAX_ALLOWANCE);
        cheats.expectRevert(bytes("Raffle not started"));
        rb.buyTickets(raffleId, 1);
    }

    function testCannotBuyTicketsAfterEnd() public {
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), MAX_ALLOWANCE);
        cheats.warp(block.timestamp + DURATION);
        cheats.expectRevert(bytes("Raffle ended"));
        rb.buyTickets(raffleId, 1);
    }
}

contract InitializeSeedTest is RaffleBurnHelper {
    function testInitializeSeed() public {
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), MAX_ALLOWANCE);
        cheats.warp(block.timestamp + DURATION);
        rb.initializeSeed(raffleId, bytes32(0), uint64(0));
        (, , , , , uint96 seed) = rb.raffles(raffleId);
        assertTrue(seed != uint96(0));
    }

    function testRaffleNotEnded() public {
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), MAX_ALLOWANCE);
        // initialize too early
        cheats.warp(block.timestamp + DURATION - 1);
        cheats.expectRevert(bytes("Raffle not ended"));
        rb.initializeSeed(raffleId, bytes32(0), uint64(0));
    }

    function testCannotInitializeSeedTwice() public {
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), MAX_ALLOWANCE);
        cheats.warp(block.timestamp + DURATION);
        rb.initializeSeed(raffleId, bytes32(0), uint64(0));
        cheats.expectRevert(bytes("Seed already requested"));
        rb.initializeSeed(raffleId, bytes32(0), uint64(0));
    }
}

contract ClaimPrizeTest is RaffleBurnHelper {
    uint256 raffleId;

    function setUp() public override {
        super.setUp();
        raffleId = createDummyRaffle(address(nft1), address(t1));

        uint96[] memory tokenIds = new uint96[](2);
        tokenIds[0] = uint96(nft2.tokenOfOwnerByIndex(a1, 0));
        tokenIds[1] = uint96(nft2.tokenOfOwnerByIndex(a1, 1));
        cheats.startPrank(a1);
        nft2.setApprovalForAll(address(rb), true);
        rb.addPrizes(raffleId, address(nft2), tokenIds);
        cheats.stopPrank();

        t1.approve(address(rb), MAX_ALLOWANCE);
        rb.buyTickets(raffleId, 5);

        cheats.startPrank(a1);
        t1.approve(address(rb), MAX_ALLOWANCE);
        rb.buyTickets(raffleId, 4);
        cheats.stopPrank();

        cheats.startPrank(a2);
        t1.approve(address(rb), MAX_ALLOWANCE);
        rb.buyTickets(raffleId, 3);
        cheats.stopPrank();
    }

    function testClaimPrize() public {
        cheats.warp(block.timestamp + DURATION);
        rb.initializeSeed(raffleId, bytes32(0), uint64(0));

        uint256 prizeIndex = 0;
        (address account, uint256 ticketPurchaseIndex, ) = rb.getWinner(
            raffleId,
            prizeIndex
        );
        rb.claimPrize(raffleId, prizeIndex, ticketPurchaseIndex);

        (, , , bool claimed) = rb.rafflePrizes(raffleId, prizeIndex);
        assertTrue(claimed);
        assertEq(nft1.ownerOf(0), account);
    }

    function testSeedNotSet() public {
        cheats.expectRevert(bytes("Seed not set"));
        rb.claimPrize(0, 0, 0);
    }

    function testNotWinnerTicket(uint32 warpOffset) public {
        cheats.warp(block.timestamp + DURATION + warpOffset);
        rb.initializeSeed(raffleId, bytes32(0), uint64(0));
        uint256 prizeIndex = 0;
        (, uint256 loserTicketPurchaseIndex) = getFirstLoser(prizeIndex);
        cheats.expectRevert(bytes("Not winner ticket"));
        rb.claimPrize(raffleId, prizeIndex, loserTicketPurchaseIndex);
    }

    function getFirstLoser(uint256 prizeIndex)
        public
        view
        returns (address account, uint256 ticketPurchaseIndex)
    {
        (address winnerAccount, , ) = rb.getWinner(raffleId, prizeIndex);

        uint256 purchaseCount = rb.getPurchaseCount(raffleId);
        for (uint256 i = 0; i < purchaseCount; i++) {
            (address owner, ) = rb.raffleTickets(raffleId, i);
            if (owner != winnerAccount) {
                return (owner, i);
            }
        }
    }
}

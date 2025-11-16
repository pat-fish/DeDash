// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeDashDynamic.sol";

// Harness to expose the DeliveryBlock struct in a clean way for testing
contract DeDashDynamicHarness is DeDashDynamic {
    function getBlock(uint256 id) external view returns (DeliveryBlock memory) {
        return blocks[id];
    }
}

contract DeDashDynamicTest is Test {
    DeDashDynamicHarness public deDash;

    address public user = address(0xAAA1);
    address public driver = address(0xBBB2);
    address public rand = address(0xCCC3);

    function setUp() public {
        deDash = new DeDashDynamicHarness();

        // Give accounts ETH to work with
        vm.deal(user, 100 ether);
        vm.deal(driver, 100 ether);
        vm.deal(rand, 100 ether);

        // Set gas price to 0 so balance assertions are deterministic
        vm.txGasPrice(0);
    }

    // --- Helpers ---

    function _createOrder(
        uint256 minPrice,
        uint256 maxPrice,
        uint256 expirationWindowSeconds
    ) internal returns (uint256 blockId) {
        vm.prank(user);
        blockId = deDash.createDeliveryBlock{value: maxPrice}(
            "Restaurant XYZ",
            "1x Burger, 1x Fries",
            "123 Dropoff Street",
            minPrice,
            maxPrice,
            expirationWindowSeconds
        );
    }

    // --- Base Tests (from before) ---

    function testCreateDeliveryBlockStoresDataAndEscrowsMaxPrice() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600; // 10 minutes

        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(deDash).balance;

        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);

        // ID & owner
        assertEq(b.id, blockId, "block id mismatch");
        assertEq(b.user, user, "user mismatch");
        assertEq(b.driver, address(0), "driver should be empty");

        // Prices & escrow
        assertEq(b.minPrice, minPrice, "minPrice mismatch");
        assertEq(b.maxPrice, maxPrice, "maxPrice mismatch");
        assertEq(b.escrow, maxPrice, "escrow should equal maxPrice");

        // Status & timestamps
        assertEq(uint8(b.status), uint8(DeDashDynamic.BlockStatus.Open), "status should be Open");
        assertEq(b.createdAt + window, b.expiresAt, "expiresAt mismatch");

        // Balances
        assertEq(userBalanceBefore - user.balance, maxPrice, "user should have paid maxPrice");
        assertEq(address(deDash).balance - contractBalanceBefore, maxPrice, "contract should hold maxPrice");
    }

    function testCurrentPriceIsMinAtCreationAndMaxAtExpiry() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        // Fix a clean timestamp
        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        // At creation time, price should be minPrice
        uint256 priceAtStart = deDash.getCurrentPrice(blockId);
        assertEq(priceAtStart, minPrice, "price at creation should be minPrice");

        // Warp to exactly expiresAt
        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);
        vm.warp(b.expiresAt);

        uint256 priceAtEnd = deDash.getCurrentPrice(blockId);
        assertEq(priceAtEnd, maxPrice, "price at expiry should be maxPrice");
    }

    function testCurrentPriceIncreasesOverTime() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);

        // Time = midpoint between createdAt and expiresAt
        uint256 midTime = b.createdAt + (window / 2);
        vm.warp(midTime);

        uint256 priceMid = deDash.getCurrentPrice(blockId);

        // For linear interpolation, midpoint should be roughly halfway between min and max
        uint256 expectedMid = minPrice + (maxPrice - minPrice) / 2;
        assertApproxEqRel(priceMid, expectedMid, 1e16, "mid price not approx halfway"); // 1% tolerance
    }

    function testDriverAcceptLocksAgreedPriceAndStatusAccepted() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        DeDashDynamic.DeliveryBlock memory bBefore = deDash.getBlock(blockId);

        // Accept halfway through window
        uint256 midTime = bBefore.createdAt + (window / 2);
        vm.warp(midTime);

        uint256 currentPrice = deDash.getCurrentPrice(blockId);

        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);

        DeDashDynamic.DeliveryBlock memory bAfter = deDash.getBlock(blockId);

        assertEq(bAfter.driver, driver, "driver not recorded");
        assertEq(
            uint8(bAfter.status),
            uint8(DeDashDynamic.BlockStatus.Accepted),
            "status should be Accepted"
        );
        assertEq(bAfter.agreedPrice, currentPrice, "agreedPrice should equal price at accept time");
    }

    function testFullHappyPathFlowDeliveryAndSettlement() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);

        uint256 userStartBalance = user.balance;
        uint256 driverStartBalance = driver.balance;
        uint256 contractStartBalance = address(deDash).balance;

        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);

        // Move to 75% of the time window
        uint256 t75 = b.createdAt + (window * 3) / 4;
        vm.warp(t75);

        uint256 priceAtAccept = deDash.getCurrentPrice(blockId);

        // Driver accepts
        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);

        // Driver marks delivered
        vm.prank(driver);
        deDash.markDelivered(blockId);

        // User confirms delivery
        vm.prank(user);
        deDash.confirmDelivery(blockId);

        DeDashDynamic.DeliveryBlock memory bAfter = deDash.getBlock(blockId);

        assertEq(
            uint8(bAfter.status),
            uint8(DeDashDynamic.BlockStatus.Completed),
            "status should be Completed"
        );
        assertEq(bAfter.escrow, 0, "escrow should be zero after completion");

        // Balances:
        uint256 userEndBalance = user.balance;
        uint256 driverEndBalance = driver.balance;
        uint256 contractEndBalance = address(deDash).balance;

        assertEq(
            userStartBalance - userEndBalance,
            priceAtAccept,
            "user net cost should equal agreed price"
        );
        assertEq(
            driverEndBalance - driverStartBalance,
            priceAtAccept,
            "driver net gain should equal agreed price"
        );
        assertEq(
            contractEndBalance,
            contractStartBalance,
            "contract should not hold funds after completion"
        );
    }

    function testExpireBlockRefundsUserWhenNoDriver() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 userStartBalance = user.balance;
        uint256 contractStartBalance = address(deDash).balance;

        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        // Move past expiration
        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);
        vm.warp(b.expiresAt + 1);

        vm.prank(user); // or anyone; function is public
        deDash.expireBlock(blockId);

        DeDashDynamic.DeliveryBlock memory bAfter = deDash.getBlock(blockId);

        assertEq(
            uint8(bAfter.status),
            uint8(DeDashDynamic.BlockStatus.Expired),
            "status should be Expired"
        );
        assertEq(bAfter.escrow, 0, "escrow should be zero after expiration");

        uint256 userEndBalance = user.balance;
        uint256 contractEndBalance = address(deDash).balance;

        // User should get full maxPrice back
        assertEq(
            userEndBalance,
            userStartBalance,
            "user should be fully refunded on expiration"
        );
        assertEq(
            contractEndBalance,
            contractStartBalance,
            "contract should hold no extra funds after refund"
        );
    }

    function testCancelBeforeAcceptanceRefundsUser() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 userStartBalance = user.balance;
        uint256 contractStartBalance = address(deDash).balance;

        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        vm.prank(user);
        deDash.cancelBlock(blockId);

        DeDashDynamic.DeliveryBlock memory bAfter = deDash.getBlock(blockId);

        assertEq(
            uint8(bAfter.status),
            uint8(DeDashDynamic.BlockStatus.Cancelled),
            "status should be Cancelled"
        );
        assertEq(bAfter.escrow, 0, "escrow should be zero after cancel");

        uint256 userEndBalance = user.balance;
        uint256 contractEndBalance = address(deDash).balance;

        // User should get full maxPrice back
        assertEq(
            userEndBalance,
            userStartBalance,
            "user should be fully refunded on cancel"
        );
        assertEq(
            contractEndBalance,
            contractStartBalance,
            "contract should hold no extra funds after cancel"
        );
    }

    function testCannotAcceptAfterExpiry() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);

        // Warp just past expiration
        vm.warp(b.expiresAt + 1);

        vm.prank(driver);
        vm.expectRevert("Order expired");
        deDash.acceptDeliveryBlock(blockId);
    }

    // --- Edge Case Tests ---

    function testMinEqualsMaxPriceConstantPrice() public {
        uint256 price = 1.5 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(price, price, window);

        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);

        // At creation
        uint256 p1 = deDash.getCurrentPrice(blockId);
        assertEq(p1, price, "price should equal min/max at creation");

        // Midway
        vm.warp(b.createdAt + window / 2);
        uint256 p2 = deDash.getCurrentPrice(blockId);
        assertEq(p2, price, "price should stay constant in middle");

        // At expiry
        vm.warp(b.expiresAt);
        uint256 p3 = deDash.getCurrentPrice(blockId);
        assertEq(p3, price, "price should stay constant at expiry");

        // Accept at expiry, ensure agreedPrice is correct
        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);
        DeDashDynamic.DeliveryBlock memory bAfter = deDash.getBlock(blockId);
        assertEq(bAfter.agreedPrice, price, "agreedPrice should equal constant price");
    }

    function testCreateOrderZeroMinPriceReverts() public {
        uint256 minPrice = 0;
        uint256 maxPrice = 1 ether;
        uint256 window = 600;

        vm.warp(1000);
        vm.prank(user);
        vm.expectRevert("minPrice > 0");
        deDash.createDeliveryBlock{value: maxPrice}(
            "R",
            "O",
            "D",
            minPrice,
            maxPrice,
            window
        );
    }

    function testCreateOrderMaxLessThanMinReverts() public {
        uint256 minPrice = 2 ether;
        uint256 maxPrice = 1 ether;
        uint256 window = 600;

        vm.warp(1000);
        vm.prank(user);
        vm.expectRevert("maxPrice >= minPrice");
        deDash.createDeliveryBlock{value: maxPrice}(
            "R",
            "O",
            "D",
            minPrice,
            maxPrice,
            window
        );
    }

    function testCreateOrderWrongEscrowValueReverts() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        vm.prank(user);
        vm.expectRevert("Send maxPrice as escrow");
        deDash.createDeliveryBlock{value: 1 ether}(
            "R",
            "O",
            "D",
            minPrice,
            maxPrice,
            window
        );
    }

    function testCreateOrderZeroExpirationReverts() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 0;

        vm.warp(1000);
        vm.prank(user);
        vm.expectRevert("Invalid expiration");
        deDash.createDeliveryBlock{value: maxPrice}(
            "R",
            "O",
            "D",
            minPrice,
            maxPrice,
            window
        );
    }

    function testUserCannotBeDriver() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        vm.prank(user);
        vm.expectRevert("User cannot be driver");
        deDash.acceptDeliveryBlock(blockId);
    }

    function testNonUserCannotCancel() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        vm.prank(rand);
        vm.expectRevert("Only user");
        deDash.cancelBlock(blockId);
    }

    function testCannotCancelAfterAccepted() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);

        vm.prank(user);
        vm.expectRevert("Cannot cancel now");
        deDash.cancelBlock(blockId);
    }

    function testCannotExpireNonOpenBlock() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        // Accept so status is Accepted
        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);

        // Warp past expiry
        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);
        vm.warp(b.expiresAt + 1);

        vm.prank(user);
        vm.expectRevert("Only open orders");
        deDash.expireBlock(blockId);
    }

    function testNonDriverCannotMarkDelivered() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);

        vm.prank(rand);
        vm.expectRevert("Only driver");
        deDash.markDelivered(blockId);
    }

    function testNonUserCannotConfirmDelivery() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);

        vm.prank(driver);
        deDash.markDelivered(blockId);

        vm.prank(rand);
        vm.expectRevert("Only user");
        deDash.confirmDelivery(blockId);
    }

    function testCannotConfirmBeforeDelivered() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 2 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);

        vm.prank(user);
        vm.expectRevert("Not delivered yet");
        deDash.confirmDelivery(blockId);
    }

    function testAcceptExactlyAtExpiryUsesMaxPrice() public {
        uint256 minPrice = 1 ether;
        uint256 maxPrice = 3 ether;
        uint256 window = 600;

        vm.warp(1000);
        uint256 blockId = _createOrder(minPrice, maxPrice, window);

        DeDashDynamic.DeliveryBlock memory b = deDash.getBlock(blockId);

        // Warp to exactly expiresAt (still allowed)
        vm.warp(b.expiresAt);

        uint256 price = deDash.getCurrentPrice(blockId);
        assertEq(price, maxPrice, "price at expiry must be maxPrice");

        vm.prank(driver);
        deDash.acceptDeliveryBlock(blockId);

        DeDashDynamic.DeliveryBlock memory bAfter = deDash.getBlock(blockId);
        assertEq(bAfter.agreedPrice, maxPrice, "agreedPrice must equal maxPrice at expiry accept");
    }
}

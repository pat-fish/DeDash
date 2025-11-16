pragma solidity ^0.8.20;

contract DeDashDynamic {
    enum BlockStatus {
        Open,       // created, not yet accepted
        Accepted,   // driver locked in
        Delivered,  // driver marked as delivered
        Completed,  // funds paid out
        Cancelled,  // cancelled by user before acceptance
        Expired     // expired without being accepted
    }

    struct DeliveryBlock {
        uint256 id;
        address user;
        address driver;

        string restaurantInfo;
        string orderDescription;
        string deliveryAddress;

        uint256 minPrice;     // lowest price user is willing to pay
        uint256 maxPrice;     // highest price user is willing to pay
        uint256 agreedPrice;  // price locked in at acceptance
        uint256 escrow;       // amount held in contract (funded with maxPrice)

        uint256 createdAt;
        uint256 expiresAt;    // last timestamp a driver can accept

        BlockStatus status;
    }

    uint256 public nextBlockId;
    mapping(uint256 => DeliveryBlock) public blocks;

    event BlockCreated(
        uint256 indexed blockId,
        address indexed user,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 expiresAt
    );

    event BlockAccepted(
        uint256 indexed blockId,
        address indexed driver,
        uint256 agreedPrice
    );

    event BlockDelivered(uint256 indexed blockId, address indexed driver);
    event BlockCompleted(
        uint256 indexed blockId,
        address indexed user,
        address indexed driver,
        uint256 paidToDriver,
        uint256 refundedToUser
    );

    event BlockCancelled(uint256 indexed blockId);
    event BlockExpired(uint256 indexed blockId);

    function createDeliveryBlock(
        string calldata restaurantInfo,
        string calldata orderDescription,
        string calldata deliveryAddress,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 expirationWindowSeconds
    ) external payable returns (uint256 blockId) {
        require(minPrice > 0, "minPrice > 0");
        require(maxPrice >= minPrice, "maxPrice >= minPrice");
        require(msg.value == maxPrice, "Send maxPrice as escrow");
        require(expirationWindowSeconds > 0, "Invalid expiration");

        blockId = nextBlockId++;
        uint256 expiresAt = block.timestamp + expirationWindowSeconds;

        blocks[blockId] = DeliveryBlock({
            id: blockId,
            user: msg.sender,
            driver: address(0),
            restaurantInfo: restaurantInfo,
            orderDescription: orderDescription,
            deliveryAddress: deliveryAddress,
            minPrice: minPrice,
            maxPrice: maxPrice,
            agreedPrice: 0,
            escrow: msg.value,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            status: BlockStatus.Open
        });

        emit BlockCreated(blockId, msg.sender, minPrice, maxPrice, expiresAt);
    }

    function getCurrentPrice(uint256 blockId) public view returns (uint256) {
        DeliveryBlock storage b = blocks[blockId];

        require(b.user != address(0), "Block does not exist");
        require(b.status == BlockStatus.Open, "Not open");

        // Before or at creation time, treat price as minPrice
        if (block.timestamp <= b.createdAt) {
            return b.minPrice;
        }

        // If we've hit or passed expiration, price is maxPrice
        if (block.timestamp >= b.expiresAt) {
            return b.maxPrice;
        }

        uint256 elapsed = block.timestamp - b.createdAt;
        uint256 duration = b.expiresAt - b.createdAt;
        uint256 diff = b.maxPrice - b.minPrice;

        // Linear interpolation:
        // price = minPrice + diff * (elapsed / duration)
        uint256 increment = (diff * elapsed) / duration;
        return b.minPrice + increment;
    }

    function acceptDeliveryBlock(uint256 blockId) external {
        DeliveryBlock storage b = blocks[blockId];

        require(b.user != address(0), "Block does not exist");
        require(b.status == BlockStatus.Open, "Not open");
        require(block.timestamp <= b.expiresAt, "Order expired");
        require(msg.sender != b.user, "User cannot be driver");

        uint256 price = getCurrentPrice(blockId);

        b.driver = msg.sender;
        b.agreedPrice = price;
        b.status = BlockStatus.Accepted;

        emit BlockAccepted(blockId, msg.sender, price);
    }

    function markDelivered(uint256 blockId) external {
        DeliveryBlock storage b = blocks[blockId];

        require(b.user != address(0), "Block does not exist");
        require(msg.sender == b.driver, "Only driver");
        require(b.status == BlockStatus.Accepted, "Not accepted");

        b.status = BlockStatus.Delivered;

        emit BlockDelivered(blockId, msg.sender);
    }

    function confirmDelivery(uint256 blockId) external {
        DeliveryBlock storage b = blocks[blockId];

        require(b.user != address(0), "Block does not exist");
        require(msg.sender == b.user, "Only user");
        require(b.status == BlockStatus.Delivered, "Not delivered yet");
        require(b.escrow >= b.agreedPrice, "Escrow < agreed price");

        uint256 totalEscrow = b.escrow;
        uint256 driverAmount = b.agreedPrice;
        uint256 refundAmount = totalEscrow - driverAmount;

        b.escrow = 0;
        b.status = BlockStatus.Completed;

        // Pay driver
        (bool s1, ) = b.driver.call{value: driverAmount}("");
        require(s1, "Driver payment failed");

        // Refund any leftover to user
        if (refundAmount > 0) {
            (bool s2, ) = b.user.call{value: refundAmount}("");
            require(s2, "Refund failed");
        }

        emit BlockCompleted(blockId, b.user, b.driver, driverAmount, refundAmount);
    }

    function expireBlock(uint256 blockId) public {
        DeliveryBlock storage b = blocks[blockId];

        require(b.user != address(0), "Block does not exist");
        require(b.status == BlockStatus.Open, "Only open orders");
        require(block.timestamp > b.expiresAt, "Not yet expired");

        uint256 refund = b.escrow;
        b.escrow = 0;
        b.status = BlockStatus.Expired;

        (bool sent, ) = b.user.call{value: refund}("");
        require(sent, "Refund failed");

        emit BlockExpired(blockId);
    }

    function cancelBlock(uint256 blockId) external {
        DeliveryBlock storage b = blocks[blockId];

        require(b.user != address(0), "Block does not exist");
        require(msg.sender == b.user, "Only user");
        require(b.status == BlockStatus.Open, "Cannot cancel now");

        uint256 refund = b.escrow;
        b.escrow = 0;
        b.status = BlockStatus.Cancelled;

        (bool sent, ) = b.user.call{value: refund}("");
        require(sent, "Refund failed");

        emit BlockCancelled(blockId);
    }
}
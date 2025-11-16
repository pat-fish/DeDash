# DeDash
### Decentralized Food Delivery Service 🚚

**DeDash** aims to provide a decentralized solution to the fee-ridden market of food delivery.  Platforms such as *Uber Eats* and *DoorDash* are notorious for their hefty fees, taking a large percentage of user's payment from drivers.  **DeDash** looks to put money back into the pockets of customers and drivers.  

Using the concept of a *Dutch Reverse Auction*, customers set a starting, maximum cost that they are willing to pay for an order, and a maximum time interval that they are willing to wait.  

The price of the delivery is dynamic; it begins at the starting price selected by the user, and gradully increments towards their max price until the order is either picked up by a nearby driver or the time limit is reached, prompting the order to be cancelled and the funds refunded to the user.

Upon the submission of an order by a customer, the user-specified maximum price is withdrawn from the user's wallet, being held on the blockchain in escrow, ensuring the user has sufficient funds and guaranteeing the driver's payment upon successful delivery.  

After successful delivery, the driver is paid the agreed order amount and the customer is reimbursed for the money that was not spent in the transaction *(escrow - final price)*.

This decentralized approach grants power to both customer and driver in price setting, removing fees found in centralized systems.  Drivers' profits don't struggle and customers pay less overall due to the lack of fees.

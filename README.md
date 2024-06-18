# RARE Bridge

## Purpose

The RARE Bridge is a set of smart contracts developed to facilitate the transfer and distribution of RARE tokens between different blockchain networks using Chainlink Cross-Chain Interoperability Protocol (CCIP). 
The bridge ensures secure and efficient communication across chains, allowing for seamless token transfers and distribution.

## Contracts

### 1. [`RareBridge.sol`](contracts/RareBridge.sol)
- **Purpose**: This abstract upgradable contract defines the core functionality for sending and receiving RARE tokens across different blockchain networks using Chainlink CCIP.
- **Key Features**:
    - Handles token transfer and distribution.
    - Manages allowlists for senders and recipients to enhance security.
    - Supports customization of default gas limits for different destination chains.
    - Emits events for sent and received messages for transparency and tracking.

### 2. [`RareBridgeLockAndUnlock.sol`](contracts/RareBridgeLockAndUnlock.sol)
- **Purpose**: Implements the lock-and-unlock mechanism for the `RareBridge` contract.
- **Key Features**:
    - Handles locking tokens on the source chain and unlocking them on the destination chain.

### 3. [`RareBridgeBurnAndMint.sol`](contracts/RareBridgeBurnAndMint.sol)
- **Purpose**: Implements the burn-and-mint mechanism for the `RareBridge` contract.
- **Key Features**:
    - Handles burning tokens on the source chain and minting them on the destination chain.

### 4. [`RareTokenL2.sol`](contracts/RareTokenL2.sol)
- **Purpose**: Upgradable ERC20 token contract for the RARE token on Layer 2 networks.
- **Key Features**:
    - Standard upgradable and pausable ERC20 with minting and burning functionality and zero initial supply.

### 5. [`CCIPReceiverUpgradable.sol`](contracts/CCIPReceiverUpgradable.sol)
- **Purpose**: Extends the functionality of the `CCIPReceiver` contract to support upgradeability through the UUPS (Universal Upgradeable Proxy Standard) pattern.
- **Key Features**:
    - Provides initialization methods for setting up the CCIP router.
    - Implements the `ccipReceive` function to handle incoming CCIP messages.

### 6. [`IRareBridge.sol`](contracts/interfaces/IRareBridge.sol)
- **Purpose**: Interface defining the events and errors for the `RareBridge` contract.
- **Key Features**:
    - Defines events for message sending and receiving activities.
    - Defines errors for bridge interactions.

### 7. [`RareBridgeWithdrawable.sol`](contracts/upgrades/RareBridgeWithdrawable.sol)
- **Purpose**: Example. Extends the `RareBridge` contract to add withdrawable functionality.
- **Key Features**:
    - Implements methods for withdrawing tokens from the bridge contract.

## Deployment Process and Interactions

### .env Templates Approach

In this project, the deployment scripts utilize `.env` template files to manage environment variables. 
Each deployment or configuration script is associated with a specific `.env` template file. 
When a script is executed, the corresponding template file is copied to `.env` to provide environment variables to Solidity scripts executed, and specific `.env.L1` or `.env.L2` files are sourced to provide the RPC_URL, PRIVATE_KEY and ETHERSCAN_API_KEY environment variables for Forge at runtime.

Here are the scripts and their associated `.env` templates:

- `deployRareBridge:L1`: Uses [`.env.deployBridgeL1`](.env.deployBridgeL1) and sources [`.env.L1`](.env.L1).
- `deployAndConfigureRareBridge:L2`: Uses [`.env.deployAndConfigureBridgeL2`](.env.deployAndConfigureBridgeL2) and sources [`.env.L2`](.env.L2).
- `configureRareBridge:L1`: Uses [`.env.configureBridgeL1`](.env.configureBridgeL1) and sources [`.env.L1`](.env.L1).
- `sendTokens:L1:L2`: Uses [`.env.sendTokensL1L2`](.env.sendTokensL1L2) and sources [`.env.L1`](.env.L1).
- `sendTokens:L2:L1`: Uses [`.env.sendTokensL2L1`](.env.sendTokensL2L1) and sources `.env.L2`.

The environment files should be filled with the appropriate values before executing the scripts.

### Prerequisites

- Node.js and npm installed. Follow the [Node.js Installation](https://nodejs.org/en/download/package-manager) documentation.
- Forge installed for building and deploying Solidity contracts. Follow the [Foundry Installation](https://book.getfoundry.sh/getting-started/installation) and [Foundry Getting Started](https://book.getfoundry.sh/getting-started/first-steps) documentation.

### Preparation

1. **Install Dependencies**: Ensure all dependencies are installed.
   ```sh
   npm install && forge install
   ```
2. **Build Contracts**: Build the contracts using Forge.
   ```sh
   npm run build
   ```

### Deployment and Configuration

#### 1. **Deploy Bridge on Layer 1**.

Deploy the `RareBridgeLockAndUnlock` contract on the source chain (Layer 1).

This script uses environment variables specified in [`.env.deployBridgeL1`](.env.deployBridgeL1) to configure the deployment process:
- `CCIP_ROUTER_ADDRESS` - address of the Chainlink CCIP router on the source chain.
- `LINK_TOKEN_ADDRESS` - address of the Chainlink LINK token on the source chain.
- `RARE_TOKEN_ADDRESS`- address of the RARE token on the source chain.

The script will:
1. Source `.env.L1` to load runtime environment variables.
2. Copy the `.env.deployBridgeL1` template to `.env` for deployment-specific configurations.
3. Deploy the Rare Bridge proxy and `RareBridgeLockAndUnlock` implementation contracts.
4. Broadcast the transaction to the network using Forge with the specified RPC URL and private key.
5. Verify the deployed contract on Etherscan using the provided API key.

   ```sh
   npm run deployBridgeL1
   ```

   > **Note**  
   > The `msg.sender` will be set as the Rare Bridge admin.  
   > You can reassign the admin role to another address later.  
   > Alternatively, you can use the [RareBridgeDeployLockAndUnlock.s.sol](script/RareBridgeDeployLockAndUnlock.s.sol) script.

#### 2. **Deploy and Configure Bridge on Layer 2**.

Deploy and configure the `RareBridgeBurnAndMint` contract on the destination chain (Layer 2).

This script uses environment variables specified in [`.env.deployAndConfigureBridgeL2`](.env.deployAndConfigureBridgeL2) to configure the deployment process:
- `CCIP_ROUTER_ADDRESS` - address of the Chainlink CCIP router on the destination chain.
- `LINK_TOKEN_ADDRESS` - address of the Chainlink LINK token on the destination chain
- `CORRESPONDENT_RARE_BRIDGE_ADDRESS` - address of the Rare Bridge contract on the source chain.
- `CORRESPONDENT_CHAIN_SELECTOR` - chain selector for the source chain.
- `CORRESPONDENT_CHAIN_GAS_LIMIT` - gas limit for the `ccipReceive()` method on the source chain.

The script will:
1. Source `.env.L2` to load runtime environment variables.
2. Copy the `.env.deployAndConfigureBridgeL2` template to `.env` for deployment-specific configurations. 
3. Deploy the `RareTokenL2` proxy and implementation contracts.
4. Deploy the Rare Bridge proxy and `RareBridgeBurnAndMint` implementation contracts.
5. Set the deployed Rare Bridge contract as the minter for the `RareTokenL2` contract.
6. Configure the Rare Bridge by allowlisting source chain and the source Rare Bridge, and setting default the gas limit for the source chain.
7. Broadcast the transactions to the network using Forge with the specified RPC URL and private key.
8. Verify the deployed contracts on Etherscan using the provided API key.

   ```sh
   npm run deployAndConfigureBridgeL2
   ```

   > **Note**  
   > The `msg.sender` will be set as the Rare Bridge admin.  
   > You can reassign the admin role to another address later.  
   > Alternatively, you can use the [RareBridgeDeployBurnAndMint.s.sol](script/RareBridgeDeployBurnAndMint.s.sol) script.

#### 3. **Configure Bridge on Layer 1**.

Configure the `RareBridge` contract on the source chain (Layer 1).

This script uses environment variables specified in [`.env.configureBridgeL1`](.env.configureBridgeL1) to configure the deployment process:
- `RARE_BRIDGE_ADDRESS` - address of the Rare Bridge contract on the source chain.
- `CORRESPONDENT_RARE_BRIDGE_ADDRESS` - address of the Rare Bridge contract on the destination chain.
- `CORRESPONDENT_CHAIN_SELECTOR` - chain selector for the destination chain.
- `CORRESPONDENT_CHAIN_GAS_LIMIT` - gas limit for the `ccipReceive()` method on the destination chain.

The script will:
1. Source `.env.L1` to load runtime environment variables.
2. Copy the `.env.configureBridgeL1` template to `.env` for deployment-specific configurations.
3. Configure the Rare Bridge contract by allowlisting destination chain and the destination Rare Bridge, and setting default the gas limit for the destination chain.
4. Broadcast the transactions to the network using Forge with the specified RPC URL and private key.

   ```sh
   npm run configureBridgeL1
   ```

### Interactions and Testing

#### 1. **Send Tokens from Layer 1 to Layer 2**

Send tokens from the source chain (Layer 1) to the destination chain (Layer 2).

This script uses environment variables specified in [`.env.sendTokensL1L2`](.env.sendTokensL1L2) to configure the deployment process:
- `RARE_TOKEN_ADDRESS` - address of the Rare Token on the source chain.
- `LINK_TOKEN_ADDRESS` - address of the Chainlink LINK token on the source chain
- `RARE_BRIDGE_ADDRESS` - address of the Rare Bridge contract on the source chain.
- `CORRESPONDENT_RARE_BRIDGE_ADDRESS` - address of the Rare Bridge contract on the destination chain.
- `CORRESPONDENT_CHAIN_SELECTOR` - chain selector for the destination chain.
- `AMOUNTS` - comma-separated array of token amounts to send.
- `RECIPIENTS` - comma-separated array of recipient addresses.
- `PAY_FEES_IN_LINK` - boolean indicating whether to pay fees in LINK tokens (true) or in the native cryptocurrency (false)

The script will:
1. Source `.env.L1` to load runtime environment variables.
2. Copy the `.env.sendTokensL1L2` template to `.env` for deployment-specific configurations.
3. Calculate fees for sending tokens based on the specified parameters.
4. Approve the Rare Bridge contract to spend the specified amounts of RARE and LINK tokens.
5. Call the `sendTokens` method on the Rare Bridge contract to send and distribute tokens to the destination chain.
6. Broadcast the transactions to the network using Forge with the specified RPC URL and private key.
   
   ```sh
   npm run sendTokensL1L2
   ```

#### 2. **Send Tokens from Layer 2 to Layer 1**

Send tokens from the destination chain (Layer 2) back to the source chain (Layer 1).

This script uses environment variables specified in [`.env.sendTokensL2L1`](.env.sendTokensL2L1) to configure the deployment process:
- `RARE_TOKEN_ADDRESS` - address of the Rare Token on the destination chain.
- `LINK_TOKEN_ADDRESS` - address of the Chainlink LINK token on the destination chain
- `RARE_BRIDGE_ADDRESS` - address of the Rare Bridge contract on the destination chain.
- `CORRESPONDENT_RARE_BRIDGE_ADDRESS` - address of the Rare Bridge contract on the source chain.
- `CORRESPONDENT_CHAIN_SELECTOR` - chain selector for the source chain.
- `AMOUNTS` - comma-separated array of token amounts to send.
- `RECIPIENTS` - comma-separated array of recipient addresses.
- `PAY_FEES_IN_LINK` - boolean indicating whether to pay fees in LINK tokens (true) or in the native cryptocurrency (false)

The script will:
1. Source `.env.L2` to load runtime environment variables.
2. Copy the `.env.sendTokensL2L1` template to `.env` for deployment-specific configurations.
3. Calculate fees for sending tokens based on the specified parameters.
4. Approve the Rare Bridge contract to spend the specified amounts of RARE and LINK tokens.
5. Call the `sendTokens` method on the Rare Bridge contract to send and distribute tokens to the destination chain.
6. Broadcast the transactions to the network using Forge with the specified RPC URL and private key.
   
   ```sh
   npm run sendTokensL2L1
   ```

### Monitoring and Tracking

The Rare Bridge emits events for sent and received messages. These events can be used to monitor and track messages sent from the source chain and received on the destination chain.

#### MessageSent

This event is emitted when a message is sent to a destination chain.

```solidity
event MessageSent(
  bytes32 indexed messageId,
  uint64 indexed destinationChainSelector,
  address indexed destinationChainRecipient,
  uint256 fee,
  bool payFeesInLink
);
```

- `messageId` - The unique ID of the CCIP message. This ID can be used to track the message through its lifecycle.
- `destinationChainSelector` - The selector of the destination chain, indicating which chain the message is being sent to.
- `destinationChainRecipient` - The address of the CCIP recipient on the destination chain. This is the address that will handle the message on the destination chain.
- `fee` - The amount of fees paid for sending the message. This can help in understanding the cost of the transaction.
- `payFeesInLink` - A boolean indicating whether the fees were paid in LINK tokens (true) or in the native cryptocurrency (false).

#### MessageReceived

This event is emitted when a message is received from a sender chain.

```solidity
event MessageReceived(
  bytes32 indexed messageId,
  uint64 indexed sourceChainSelector,
  address indexed sourceChainSender
);
```

- `messageId` - The unique ID of the CCIP message. This ID can be used to track the message through its lifecycle.
- `sourceChainSelector` - The selector of the source chain, indicating which chain the message is coming from.
- `sourceChainSelector` - The address of the CCIP sender on the source chain. This is the address that originally sent the message on the source chain.

#### Tracking CCIP Messages

To track the current status of CCIP messages, you can use the Chainlink CCIP Explorer by providing the CCIP Message ID or Tx Hash: https://ccip.chain.link/.

### Upgrade Contracts

To upgrade the Rare Bridge contracts, you can use the UUPS (Universal Upgradeable Proxy Standard) pattern.


The `RareBridge`, `RareBridgeLockAndUnlock`, and `RareBridgeBurnAndMint` contracts are designed to be upgradeable. You can deploy new implementations of these contracts and update the proxy contracts to point to the new implementations.

In order to test the upgrade functionality, you can use the provided script [RareBridgeUpgradeWithdrawable.s.sol](script/RareBridgeUpgradeWithdrawable.s.sol). This script deploys a new example implementation contract [RareBridgeWithdrawable.sol](contracts/upgrades/RareBridgeWithdrawable.sol) and updates the proxy contract to point to the new implementation.

## Additional Notes

Chainlink-related parameters, including CCIP Router addresses, LINK Token addresses, and Chain Selectors, can be found in the documentation for Chainlink CCIP:
- [Mainnets](https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet)
- [Testnets](https://docs.chain.link/ccip/supported-networks/v1_2_0/testnet)

While sending tokens from Layer 1 to Layer 2 and back, ensure that the gas limit is correctly set. 
This parameter should align with the number of token recipients. 
To estimate the gas limit for the `ccipReceive()` method on a destination chain, you can follow the [guide](https://docs.chain.link/ccip/tutorials/ccipreceive-gaslimit) provided by Chainlink.
Also, refer to the [CCIP Service Limits](https://docs.chain.link/ccip/service-limits) when setting the gas limit and sending a CCIP message.

# DeFi Stablecoin Foundry

A decentralized stablecoin system built with Solidity and Foundry, featuring algorithmic stability and exogenous collateral (ETH & BTC).

## Overview

This project implements a decentralized stablecoin system similar to DAI, but with a simpler design focused on algorithmic stability and exogenous collateral. The system maintains a 1:1 peg with USD and is backed by WETH and WBTC.

### Key Features

- **Exogenous Collateral**: Backed by WETH and WBTC
- **Dollar Pegged**: Maintains 1:1 parity with USD
- **Algorithmic Stability**: Uses a collateralization ratio to maintain stability
- **Liquidation Mechanism**: Includes a 10% bonus for liquidators
- **Health Factor**: Ensures system solvency through collateralization checks

## Technical Details

### Core Components

1. **DecentralizedStableCoin (DSC)**
   - ERC20 token implementation
   - Burnable and Ownable
   - Maintains 1:1 USD peg

2. **DscEngine**
   - Core contract handling all system logic
   - Manages collateral deposits and withdrawals
   - Handles DSC minting and burning
   - Implements liquidation mechanism
   - Uses Chainlink price feeds for collateral valuation

### Key Parameters

- **Liquidation Threshold**: 50% (200% overcollateralized)
- **Liquidation Bonus**: 10%
- **Minimum Health Factor**: 1e18
- **Precision**: 1e18

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for development tools)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/defi-stablecoin-foundry.git
cd defi-stablecoin-foundry
```

2. Install dependencies:
```bash
forge install
```

### Testing

Run the test suite:
```bash
forge test
```

For detailed test output:
```bash
forge test -vv
```

## Contract Architecture

### Main Contracts

1. **DecentralizedStableCoin.sol**
   - ERC20 implementation
   - Minting and burning functionality
   - Access control through Ownable

2. **DscEngine.sol**
   - Collateral management
   - DSC minting/burning
   - Liquidation mechanism
   - Health factor calculations
   - Price feed integration

### Key Functions

- `depositCollateral`: Deposit collateral tokens
- `mintDsc`: Mint new DSC tokens
- `redeemCollateral`: Withdraw collateral
- `burnDsc`: Burn DSC tokens
- `liquidate`: Liquidate undercollateralized positions

## Security Features

- ReentrancyGuard implementation
- Health factor checks
- Collateralization ratio monitoring
- Price feed staleness checks
- Access control mechanisms

## Development

### Testing Strategy

The project includes:
- Unit tests
- Integration tests
- Fuzz tests
- Invariant tests

### Best Practices

- Follows CEI (Checks-Effects-Interactions) pattern
- Implements comprehensive error handling
- Uses events for important state changes
- Includes detailed NatSpec documentation

## License

MIT License

## Author

Yuri Improof

## Acknowledgments

- Inspired by MakerDAO's DAI system
- Uses OpenZeppelin contracts
- Integrates with Chainlink price feeds

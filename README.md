# Blockchain-Based Fertilizer Voucher System

A transparent and efficient smart contract system for managing agricultural fertilizer vouchers on the Stacks blockchain.

## Features

- **Farmer Registration**: Secure registration and verification workflow
- **Voucher Management**: Transparent issuance and redemption tracking
- **Authorization Control**: Role-based access for voucher distribution
- **Transaction History**: Immutable record of all voucher operations
- **Balance Tracking**: Real-time voucher balance management

## Technology Stack

- **Blockchain**: Stacks (Bitcoin L2)
- **Smart Contract Language**: Clarity v3
- **Development Framework**: Clarinet
- **Testing**: Vitest + Clarinet SDK
- **CI/CD**: GitHub Actions

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm (for testing)

### Installation

```bash
git clone https://github.com/Habilafriday09/Blockchain-Fertilizer-Voucher.git
cd Blockchain-Fertilizer-Voucher
npm install
```

### Testing

```bash
# Check contract syntax
clarinet check

# Run test suite
npm test
```

## Smart Contract Functions

### Farmer Management
- `register-farmer`: Register new farmers
- `verify-farmer`: Verify farmer eligibility
- `get-farmer-info`: Retrieve farmer details

### Voucher Operations
- `issue-vouchers`: Distribute vouchers to farmers
- `redeem-vouchers`: Redeem vouchers for fertilizer
- `get-voucher-balance`: Check farmer balance

### Administration
- `add-authorized-issuer`: Grant issuance privileges
- `remove-authorized-issuer`: Revoke privileges

## Security

- Role-based access control
- Verification requirements
- Balance validation
- Immutable transaction records

## License

MIT License


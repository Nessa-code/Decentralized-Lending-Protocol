# Lending Protocol - Decentralized Lending on Stacks

A comprehensive lending protocol that allows users to deposit collateral and borrow against it with automated liquidation mechanisms.

## Features

- **Collateral Management**: Deposit and withdraw STX as collateral
- **Borrowing**: Borrow against deposited collateral with proper ratios
- **Liquidation System**: Automated liquidation when health factor drops
- **Interest Calculations**: Dynamic interest rate calculations
- **Health Monitoring**: Real-time health factor tracking

## Contract Functions

### Public Functions

- `deposit-collateral(amount)` - Deposit STX as collateral
- `withdraw-collateral(amount)` - Withdraw collateral (if safe)
- `borrow(amount)` - Borrow against collateral
- `repay(amount)` - Repay borrowed amount
- `liquidate(user, repay-amount)` - Liquidate undercollateralized positions

### Read-Only Functions

- `get-user-collateral(user)` - Get user's collateral amount
- `get-user-borrowed(user)` - Get user's borrowed amount
- `get-health-factor(user)` - Calculate user's health factor
- `can-liquidate(user)` - Check if user can be liquidated
- `get-max-borrow(user)` - Get maximum borrowable amount

### Admin Functions

- `set-collateral-ratio(new-ratio)` - Update collateral ratio (owner only)
- `set-interest-rate(new-rate)` - Update interest rate (owner only)

## Protocol Parameters

- **Collateral Ratio**: 150% (minimum collateralization)
- **Liquidation Threshold**: 120% (liquidation trigger)
- **Interest Rate**: 5% annual
- **Liquidation Bonus**: 5% (incentive for liquidators)

## Usage

1. Deposit STX as collateral using `deposit-collateral`
2. Borrow up to 66.67% of collateral value using `borrow`
3. Monitor health factor to avoid liquidation
4. Repay loans using `repay` function
5. Withdraw excess collateral when safe

## Risk Management

- Health factor must stay above 120% to avoid liquidation
- Liquidators receive 5% bonus for maintaining protocol health
- Interest accrues over time based on borrowed amount

## Testing

Run tests with Clarinet:
\`\`\`bash
clarinet test
\`\`\`
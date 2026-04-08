# CrowdFungible

CrowdFungible is a Rails host app that demonstrates a paper-trading request flow on top of Rubot.

The product UI handles trade submission and request history. Rubot admin remains the operator surface for traces, approvals, replay, and tool visibility.

## Local Setup

1. Install gems:

```bash
bundle install --local
```

2. Install and migrate the database:

```bash
bundle exec rails db:migrate
```

3. Start the app:

```bash
bundle exec rails server
```

4. Open:

- Product UI: `http://localhost:3000/`
- Rubot admin: `http://localhost:3000/rubot/admin`

## Configuration

### Rubot

- `config/initializers/rubot.rb`
- `config/rubot.yml`

### CrowdFungible

- `CROWDFUNGIBLE_BROKER_MODE`
  Development and test default to `fake`. Set to `alpaca` for live paper-trading calls.
- `ALPACA_API_KEY`
- `ALPACA_SECRET_KEY`
- `ALPACA_PAPER_BASE_URL`
  Defaults to `https://paper-api.alpaca.markets`
- `ALPACA_MARKET_DATA_URL`
  Defaults to `https://data.alpaca.markets`
- `CROWDFUNGIBLE_AUTO_APPROVAL_NOTIONAL_THRESHOLD`
  Defaults to `1000`
- `CROWDFUNGIBLE_CONCENTRATION_THRESHOLD`
  Defaults to `0.25`
- `CROWDFUNGIBLE_LOW_BUYING_POWER_THRESHOLD`
  Defaults to `1000`
- `CROWDFUNGIBLE_SYMBOL_ALLOWLIST`
  Defaults to `AAPL,AMZN,GOOGL,META,MSFT,NVDA,TSLA`

## Demo Scenarios

- Small clear buy that auto-executes: `Buy 2 shares of AAPL`
- Ambiguous request that routes to approval: `Put $500 into NVDA if cash is available`
- Invalid symbol that rejects: `Buy 5 shares of ZZZZ`
- Oversized order that requires approval: `Buy $5000 of NVDA`

## Tests

```bash
bundle exec rails test
```

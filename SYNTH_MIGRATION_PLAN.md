# Synth Finance API Migration Plan

## Overview
Synth Finance has shut down, requiring migration to alternative APIs for:
1. Exchange rates (forex data)
2. Stock/security prices
3. Company logos

## Current Synth API Usage

### API Endpoints Used:
- `GET /rates/historical` - Single historical exchange rate
- `GET /rates/historical-range` - Range of historical exchange rates  
- `GET /tickers/search` - Search for securities
- `GET /tickers/{symbol}` - Get security information
- `GET /tickers/{symbol}/open-close` - Get historical stock prices
- `GET /user` - Check API health and usage
- `https://logo.synthfinance.com/{domain}` - Institution logos
- `https://logo.synthfinance.com/ticker/{ticker}` - Security logos

### Files Affected:
- `/app/models/provider/synth.rb` - Main provider implementation
- `/app/models/provider/registry.rb` - Provider registration
- `/app/models/exchange_rate/provided.rb` - Exchange rate interface
- `/app/models/security/provided.rb` - Security interface
- `/app/controllers/settings/hostings_controller.rb` - Settings controller
- `/app/views/settings/hostings/_synth_settings.html.erb` - Settings view
- `/app/views/accounts/_logo.html.erb` - Account logos
- `/app/views/holdings/show.html.erb` - Holdings logos
- `/app/views/holdings/_holding.html.erb` - Holding item logos
- `/app/models/family/auto_merchant_detector.rb` - Logo URL constant
- `/lib/tasks/securities.rake` - Security backfill task
- `.env.example` - Environment variable documentation
- `.env.test.example` - Test environment variables
- `.env.local.example` - Local development variables

## Recommended Replacement APIs

### 1. Exchange Rates: **Exchangerate-API**
- **Free Tier**: 1,500 requests/month
- **Paid Tiers**: Starting at $9/month for 100,000 requests
- **Pros**: 
  - Simple REST API
  - Historical data available
  - 161 currencies supported
  - No credit card required for free tier
  - Good documentation
- **Cons**: 
  - Rate limits on free tier
  - Historical data only on paid plans
- **Alternative**: Exchangerate.host (no API key, completely free, but less reliable)

### 2. Stock Prices: **Financial Modeling Prep (FMP)**
- **Free Tier**: 250 requests/day
- **Paid Tiers**: Starting at $15/month for 500 requests/day
- **Pros**:
  - Comprehensive stock data
  - Historical prices
  - Company information
  - Free tier available
  - Good for self-hosted apps
- **Cons**:
  - Lower free tier limits
  - Requires API key
- **Alternative**: Alpha Vantage (500 requests/day free, but slower)

### 3. Company Logos: **Clearbit Logo API**
- **Free**: No API key required
- **Format**: `https://logo.clearbit.com/{domain}`
- **Pros**:
  - Completely free
  - No authentication
  - Good coverage
- **Cons**:
  - No stock ticker logo support (only domains)
- **Alternative**: Logo.dev (free tier), or fallback to first letter icons

## Implementation Strategy

### Phase 1: Create Multi-Provider Architecture
1. Make the provider registry support multiple providers per concept
2. Create new provider classes:
   - `Provider::ExchangerateApi` (exchange rates)
   - `Provider::FinancialModelingPrep` (stock prices)
3. Update registry to support fallback chains

### Phase 2: Implement New Providers
1. **ExchangerateApi Provider**:
   - Implement `fetch_exchange_rate(from:, to:, date:)`
   - Implement `fetch_exchange_rates(from:, to:, start_date:, end_date:)`
   - Handle rate limiting and caching
   
2. **FinancialModelingPrep Provider**:
   - Implement `search_securities(symbol, ...)`
   - Implement `fetch_security_info(symbol:, ...)`
   - Implement `fetch_security_prices(symbol:, ...)`
   - Handle rate limiting and caching

### Phase 3: Update Logo URLs
1. Replace Synth logo URLs with Clearbit
2. Add fallback to existing uploaded logos or generated icons
3. Update merchant logo detection

### Phase 4: Update Configuration
1. Update environment variables:
   - Add `EXCHANGERATE_API_KEY` (optional - free tier doesn't need it)
   - Add `FMP_API_KEY`
   - Remove `SYNTH_API_KEY` references
2. Update settings page to show new API configurations
3. Add migration guide for existing users

### Phase 5: Testing & Migration
1. Test all exchange rate fetching
2. Test all security price fetching
3. Test logo fallbacks
4. Create data migration script if needed
5. Update documentation

## Environment Variables

### New Variables:
```bash
# Exchange Rates - Exchangerate-API (https://www.exchangerate-api.com/)
EXCHANGERATE_API_KEY=  # Optional for free tier (1500 req/month)

# Stock Prices - Financial Modeling Prep (https://financialmodelingprep.com/)
FMP_API_KEY=  # Required (250 req/day free)
```

### Deprecated Variables:
```bash
# SYNTH_API_KEY=  # No longer used
```

## Migration Steps for Self-Hosters

1. Sign up for free API keys:
   - Exchangerate-API: https://www.exchangerate-api.com/
   - Financial Modeling Prep: https://financialmodelingprep.com/developer/docs/
   
2. Update `.env` file with new API keys

3. Restart the application

4. Optionally backfill historical data if needed

## Alternative Approaches

### Option A: Use only free, no-auth APIs
- Exchange Rates: Exchangerate.host (no auth)
- Stock Prices: Yahoo Finance (unofficial, no auth but unreliable)
- **Pros**: No API key management
- **Cons**: Less reliable, no SLA

### Option B: Use ECB for Exchange Rates
- European Central Bank provides free exchange rate data
- **Pros**: Official, reliable, free
- **Cons**: Limited to EUR base currency, requires more complex implementation

### Option C: Implement caching layer
- Cache all API responses aggressively
- Reduce API calls by 90%+
- **Pros**: Lower API usage, faster responses
- **Cons**: Additional complexity

## Recommended Approach

**Hybrid Strategy**:
1. Use **Exchangerate-API** with free tier for exchange rates (with generous caching)
2. Use **Financial Modeling Prep** with free tier for stock prices (with caching)
3. Use **Clearbit** for institution logos (free)
4. Keep existing fallbacks to user-uploaded logos and generated icons for tickers
5. Implement aggressive caching to stay within free tiers for most self-hosted users
6. Document paid tier options for power users

## Success Criteria

- [ ] All exchange rate functionality works with new provider
- [ ] All stock price functionality works with new provider
- [ ] Logos display correctly with new sources
- [ ] Free tier limits are sufficient for typical self-hosted usage
- [ ] Settings page updated with new API configuration options
- [ ] Documentation updated
- [ ] Migration guide created for existing users
- [ ] No references to Synth remain in codebase

## Next Steps

1. Review and approve this plan
2. Implement Phase 1 (multi-provider architecture)
3. Implement Phase 2 (new providers)
4. Implement Phase 3 (logo updates)
5. Test thoroughly
6. Deploy and document

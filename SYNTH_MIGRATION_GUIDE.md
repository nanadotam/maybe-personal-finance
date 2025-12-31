# Migration Guide: Replacing Synth Finance API

## Overview

Synth Finance has shut down as of December 2024. This guide will help you migrate your Maybe self-hosted instance to use the new market data providers.

## What's Changed

### New Providers

1. **ExchangerateApi** - For exchange rates
   - Free tier: 1,500 requests/month
   - Paid tier: Starting at $9/month for 100,000 requests
   - Website: https://www.exchangerate-api.com/

2. **Financial Modeling Prep (FMP)** - For stock prices and securities data
   - Free tier: 250 requests/day  
   - Paid tier: Starting at $15/month for 500 requests/day
   - Website: https://financialmodelingprep.com/

### What's Been Updated

- **Exchange Rate Fetching**: Now uses ExchangerateApi instead of Synth
- **Stock Price Fetching**: Now uses Financial Modeling Prep instead of Synth
- **Company Logos**: Institution logos now use Clearbit (free, no auth)
- **Stock Ticker Logos**: Now stored in database from FMP API, with fallback to generated icons

## Migration Steps

### 1. Sign Up for New API Keys

#### ExchangerateApi (Required for exchange rates)

1. Visit https://www.exchangerate-api.com/
2. Sign up for a free account
3. Copy your API key from the dashboard
4. The free tier provides 1,500 requests/month

#### Financial Modeling Prep (Required for stock prices)

1. Visit https://financialmodelingprep.com/developer/docs/
2. Sign up for a free account
3. Navigate to your dashboard to get your API key
4. The free tier provides 250 requests/day

### 2. Update Environment Variables

Update your `.env` file with the new API keys:

```bash
# Remove or comment out (no longer used)
# SYNTH_API_KEY=your_old_synth_key

# Add new providers
EXCHANGERATE_API_KEY=your_exchangerate_api_key
FMP_API_KEY=your_fmp_api_key
```

### 3. Restart Your Application

After updating your environment variables, restart your Maybe instance:

```bash
# If using Docker Compose
docker-compose restart

# If running natively
# Stop the server (Ctrl+C) and restart with:
bin/dev
```

### 4. Configure via Settings Page (Alternative)

Instead of using environment variables, you can also configure the API keys through the Maybe web interface:

1. Log in to your Maybe instance
2. Navigate to Settings > Hosting
3. Enter your API keys in the "Market Data Providers" section
4. The keys will be saved and used automatically

### 5. Verify Configuration

1. Navigate to Settings > Hosting in your Maybe instance
2. You should see the status of your new API providers
3. If configured correctly, you'll see:
   - "Free Tier" plan information for each provider
   - No error messages

### 6. Backfill Historical Data (Optional)

If you want to refresh your historical data with the new providers:

```bash
# This will fetch missing exchange rates and stock prices
rails marketdata:sync
```

## Frequently Asked Questions

### What happens to my existing data?

All your existing exchange rates and stock prices remain in the database. The new providers will only be used for:
- Fetching new data going forward
- Filling in any missing historical data

### Do I need both API keys?

- **EXCHANGERATE_API_KEY**: Required if you have accounts in multiple currencies
- **FMP_API_KEY**: Required if you track stocks, ETFs, or other securities

If you only use one currency and don't track securities, you may only need one provider.

### What if I exceed the free tier limits?

The app will continue to work with cached data. You have two options:
1. Upgrade to a paid tier for the provider you're exceeding
2. Wait for your monthly/daily quota to reset

### Can I still use Synth?

No. Synth Finance has permanently shut down, and their API no longer responds. The integration has been kept in the code for backwards compatibility, but it won't work.

### Are logos still available?

Yes:
- **Institution logos** (like banks): Now use Clearbit (free, no authentication required)
- **Stock ticker logos**: Provided by FMP API and stored in the database
- **Fallback**: Generated icon-style logos based on the first letter

### How much does this cost?

Both providers offer generous free tiers:
- ExchangerateApi: 1,500 requests/month (usually sufficient for personal use)
- FMP: 250 requests/day (7,500 requests/month)

For most self-hosted personal finance apps, the free tiers should be sufficient.

## Troubleshooting

### "No provider configured" warning

**Problem**: You see warnings about missing market data providers.

**Solution**: Make sure you've configured at least one API key:
- For exchange rates: Set `EXCHANGERATE_API_KEY`
- For securities: Set `FMP_API_KEY`

### Exchange rates not updating

**Problem**: Exchange rates aren't being fetched.

**Solution**: 
1. Verify your `EXCHANGERATE_API_KEY` is set correctly
2. Check Settings > Hosting to see if there are any errors
3. Ensure you haven't exceeded your API quota

### Stock prices not updating

**Problem**: Stock prices aren't being fetched.

**Solution**:
1. Verify your `FMP_API_KEY` is set correctly  
2. Check Settings > Hosting to see if there are any errors
3. The free tier has daily limits - you may need to wait until the next day

### Logos not displaying

**Problem**: Company or stock logos are missing.

**Solution**:
- Institution logos use Clearbit - make sure the domain is correct
- Stock logos come from FMP - verify your FMP API key is configured
- Fallback icons should appear if logos aren't available

## API Rate Limit Recommendations

To stay within free tier limits:

1. **Enable aggressive caching** (default in Maybe)
   - Historical data is cached permanently
   - Current prices are cached for several hours

2. **Import data in batches**
   - Don't try to backfill years of data at once
   - Spread out large imports over multiple days

3. **Monitor your usage**
   - Check the Settings > Hosting page regularly
   - Both providers show usage statistics

## Need Help?

- Check the [Maybe GitHub Issues](https://github.com/maybe-finance/maybe/issues)
- Review provider documentation:
  - [ExchangerateApi Docs](https://www.exchangerate-api.com/docs)
  - [FMP API Docs](https://financialmodelingprep.com/developer/docs/)

## Rollback (Not Recommended)

**Note**: Since Synth Finance has shut down, rolling back is not possible. If you encounter issues with the new providers, please file a GitHub issue.

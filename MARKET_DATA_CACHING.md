# Market Data Caching Guide

## Overview

To minimize API calls and stay within free tier limits, Maybe implements a sophisticated **multi-layer caching system** for market data (exchange rates and security prices).

## Caching Architecture

### Three-Layer Cache Strategy

```
┌─────────────────────────────────────────────────────┐
│  Request for Exchange Rate / Security Price         │
└─────────────────┬───────────────────────────────────┘
                  │
                  ▼
      ┌───────────────────────┐
      │  Layer 1: Rails Cache │ ◄── Fastest (in-memory)
      │  (Memory/Redis)       │     Time-limited (15min-24hr)
      └───────────┬───────────┘
                  │ Cache Miss
                  ▼
      ┌───────────────────────┐
      │  Layer 2: Database    │ ◄── Fast (indexed)
      │  (PostgreSQL)         │     Permanent storage
      └───────────┬───────────┘
                  │ Not Found
                  ▼
      ┌───────────────────────┐
      │  Layer 3: External API│ ◄── Slowest
      │  (Only when needed)   │     Rate-limited
      └───────────────────────┘
```

### Cache Durations

#### Exchange Rates
- **Duration**: 24 hours
- **Reason**: Exchange rates don't change dramatically within a day
- **API**: ExchangerateApi (1,500 requests/month free)

#### Security Prices
- **Current prices** (today): 15 minutes
- **Recent prices** (last 7 days): 1 hour  
- **Historical prices** (>7 days): 24 hours
- **Reason**: Current prices are volatile, historical prices rarely change
- **API**: Financial Modeling Prep (250 requests/day free)

## How It Works

### Exchange Rates Example

```ruby
# User views their net worth with multiple currencies
# 1st request: Fetches from API, stores in DB + cache
ExchangeRate.find_or_fetch_rate_with_cache(from: "USD", to: "EUR", date: Date.today)
# → API call made, data cached for 24 hours

# 2nd request (within 24 hours): Served from cache
ExchangeRate.find_or_fetch_rate_with_cache(from: "USD", to: "EUR", date: Date.today)
# → Instant response, NO API call

# After 24 hours: Cache expires, checks database first
# Database still has the rate, so NO API call unless data missing
```

### Security Prices Example

```ruby
# User views AAPL stock
security = Security.find_by(ticker: "AAPL")

# Today's price (cached 15 minutes)
security.find_or_fetch_price_with_cache(date: Date.current)
# → Refreshes every 15 minutes during market hours

# Last week's price (cached 1 hour)
security.find_or_fetch_price_with_cache(date: 7.days.ago)
# → Less frequent updates needed

# Historical price from 2020 (cached 24 hours)
security.find_or_fetch_price_with_cache(date: Date.new(2020, 1, 1))
# → Rarely changes, cached longest
```

## API Call Reduction

### Without Caching
- User refreshes net worth page: **~5-10 API calls**
- 100 page views/day: **500-1,000 API calls/day**
- **Exceeds free tier in 2-3 days** ❌

### With Caching
- User refreshes net worth page: **0 API calls** (cached)
- 100 page views/day: **~5-10 API calls/day** (only for new data)
- **Stays within free tier easily** ✅

### Estimated Savings
- **Exchange rates**: 95%+ reduction in API calls
- **Security prices**: 90%+ reduction in API calls

## Cache Management

### View Cache Statistics

```bash
rails market_data:cache_stats
```

Output:
```
=== Market Data Cache Statistics ===

Exchange Rates:
  - Database records: 245
  - Cache strategy: 24-hour TTL
  - Provider: Provider::ExchangerateApi

Security Prices:
  - Database records: 1,523
  - Securities tracked: 12
  - Cache strategy: 15min (current), 1hour (recent), 24hour (historical)
  - Provider: Provider::FinancialModelingPrep
```

### Clear All Caches

```bash
# Clear everything (if you want fresh data)
rails market_data:clear_cache

# Clear only exchange rates
rails market_data:clear_exchange_rate_cache

# Clear only security prices
rails market_data:clear_security_price_cache
```

### Warm Up Cache (Preload Common Data)

```bash
# Pre-fetch commonly used exchange rates
rails market_data:warm_cache
```

This is useful after:
- Fresh installation
- Clearing caches
- Adding new accounts/securities

### Monitor API Usage

```bash
rails market_data:monitor_usage
```

Output:
```
=== API Usage Monitoring ===

Exchange Rate Provider: Provider::ExchangerateApi
  - Used: 45
  - Limit: 1500
  - Utilization: 3.0%
  - Plan: Free Tier

Security Provider: Provider::FinancialModelingPrep
  - Used: 23
  - Limit: 250
  - Utilization: 9.2%
  - Plan: Free Tier
```

## Best Practices

### 1. Don't Clear Caches Unnecessarily
- Cached data is still accurate
- Clearing forces expensive API calls
- Only clear if data seems incorrect

### 2. Warm Cache After Setup
```bash
rails market_data:warm_cache
```
- Pre-loads commonly used rates
- Better user experience (faster page loads)

### 3. Monitor API Usage Regularly
```bash
rails market_data:monitor_usage
```
- Check you're staying within free tiers
- Upgrade to paid tier if needed

### 4. Use Batch Operations
```ruby
# Good: Batch fetch (1 API call)
dates = [Date.today, 1.day.ago, 2.days.ago]
ExchangeRate.find_or_fetch_rates_batch(from: "USD", to: "EUR", dates: dates)

# Bad: Individual fetches (3 API calls)
dates.each do |date|
  ExchangeRate.find_or_fetch_rate(from: "USD", to: "EUR", date: date)
end
```

### 5. Let Cache Expire Naturally
- Trust the TTL (time-to-live) settings
- Cache durations are optimized for accuracy vs. API usage
- Historical data rarely needs refreshing

## Cache Storage Options

### Development (Default: Memory Store)
- Fast, simple
- Cleared on app restart
- Good for development

### Production (Recommended: Redis)

Add to your `.env`:
```bash
REDIS_URL=redis://localhost:6379/0
```

Update `config/environments/production.rb`:
```ruby
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
```

**Benefits**:
- Persistent across app restarts
- Shared across multiple app instances
- Better performance at scale

## Troubleshooting

### Problem: Too Many API Calls

**Check**:
```bash
rails market_data:monitor_usage
```

**Solutions**:
1. Verify caching is working:
   ```bash
   rails market_data:cache_stats
   ```

2. Check Redis/cache store is configured:
   ```bash
   rails runner "puts Rails.cache.class"
   ```

3. Increase cache durations (if acceptable):
   ```ruby
   # config/initializers/market_data_caching.rb
   # Adjust durations as needed
   ```

### Problem: Stale Data

**Check cache age**:
- Exchange rates: Up to 24 hours old
- Current stock prices: Up to 15 minutes old
- Historical prices: Up to 24 hours old

**Force refresh**:
```bash
# Clear specific rate
rails runner "ExchangeRate.clear_rate_cache(from: 'USD', to: 'EUR', date: Date.today)"

# Or clear all
rails market_data:clear_cache
```

### Problem: Cache Miss Ratio Too High

**Warm up the cache**:
```bash
rails market_data:warm_cache
```

**Check database**:
```ruby
# Should have data
ExchangeRate.count
Security::Price.count
```

## Performance Metrics

### Expected Performance

| Metric | Without Cache | With Cache |
|--------|--------------|------------|
| Exchange rate lookup | ~200-500ms | ~1-5ms |
| Security price lookup | ~300-600ms | ~1-5ms |
| Page load (net worth) | 2-3 seconds | 0.5-1 second |
| API calls/day (100 users) | 50,000+ | 500-1,000 |

### Free Tier Sustainability

| Provider | Free Limit | Cached Usage | Sustainability |
|----------|-----------|--------------|----------------|
| ExchangerateApi | 1,500/month | ~50-100/month | ✅ Excellent |
| Financial Modeling Prep | 250/day | ~10-20/day | ✅ Excellent |

## Advanced Caching

### Custom Cache Duration

```ruby
# In app/models/exchange_rate/caching.rb
CACHE_DURATION = 12.hours  # Change from 24 hours
```

### Disable Caching (Not Recommended)

```ruby
# Force API call every time
ExchangeRate.find_or_fetch_rate(from: "USD", to: "EUR", cache: false)
```

### Programmatic Cache Management

```ruby
# Clear specific rate
ExchangeRate.clear_rate_cache(from: "USD", to: "EUR", date: Date.today)

# Clear all rates
ExchangeRate.clear_all_rate_caches

# Clear specific security price
security.clear_price_cache(date: Date.today)

# Clear all prices for security
security.clear_all_price_caches
```

## Summary

✅ **Multi-layer caching** minimizes API calls  
✅ **Intelligent TTL** balances freshness vs. API usage  
✅ **90-95% reduction** in API calls  
✅ **Free tiers sufficient** for most users  
✅ **Background jobs** can warm cache  
✅ **Easy monitoring** with rake tasks  

The caching system is **automatic** and requires **no user intervention** for normal operation.

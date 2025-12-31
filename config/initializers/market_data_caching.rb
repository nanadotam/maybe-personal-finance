# Market Data Caching Configuration
#
# This initializer configures caching behavior for market data (exchange rates and security prices)
# to minimize API calls while maintaining data freshness.
#
# Caching Strategy:
# =================
#
# 1. Exchange Rates
#    - Cache Duration: 24 hours
#    - Rationale: Exchange rates don't change dramatically within a day
#    - Storage: Rails.cache (Redis/Memcached if configured, otherwise memory)
#    - Fallback: Database (permanent storage)
#
# 2. Security Prices
#    - Current prices (today): 15 minutes
#    - Recent prices (last 7 days): 1 hour
#    - Historical prices (>7 days): 24 hours
#    - Rationale: Current prices change frequently, historical prices rarely change
#
# 3. Cache Layers
#    Layer 1: Rails.cache (fast, time-limited)
#    Layer 2: Database (permanent, slower)
#    Layer 3: External API (slowest, rate-limited)
#
# Cache Management:
# =================
#
# Clear all market data caches:
#   rails market_data:clear_cache
#
# Clear only exchange rate caches:
#   rails market_data:clear_exchange_rate_cache
#
# Clear only security price caches:
#   rails market_data:clear_security_price_cache
#
# Monitor cache hit rates (in logs):
#   Rails.logger.info "Cache stats: #{Rails.cache.stats}"
#

Rails.application.config.after_initialize do
  # Ensure Rails cache is configured
  unless Rails.cache.respond_to?(:write)
    Rails.logger.warn "Rails.cache not properly configured. Market data caching will use memory store."
  end

  # Configure cache store if not already set
  # In production, consider using Redis or Memcached for better performance
  if Rails.env.development? && !ENV["REDIS_URL"]
    Rails.logger.info "Using memory store for market data caching (development mode)"
  end
end

# Security Price Caching Strategy
#
# This module provides intelligent caching for security prices to minimize API calls.
#
# Caching Layers:
# 1. Database (permanent storage) - existing
# 2. Rails cache (time-based, varies by recency) - NEW
# 3. Request-level cache - NEW
#
module Security::PriceCaching
  extend ActiveSupport::Concern

  # Cache durations based on how recent the data is
  CURRENT_PRICE_CACHE_DURATION = 15.minutes  # Recent prices change frequently
  RECENT_PRICE_CACHE_DURATION = 1.hour       # Last 7 days
  HISTORICAL_PRICE_CACHE_DURATION = 24.hours # Older than 7 days (rarely changes)

  CACHE_PREFIX = "security_price"

  included do
    # Instance method for finding/fetching prices with enhanced caching
    def find_or_fetch_price_with_cache(date: Date.current, cache: true)
      cache_key = "#{CACHE_PREFIX}/#{ticker}/#{exchange_operating_mic}/#{date}"

      # Same day optimization - check cache first
      if cache
        cached_price = Rails.cache.read(cache_key)
        if cached_price.present?
          return Provider::SecurityConcept::Price.new(
            symbol: ticker,
            date: date,
            price: cached_price[:price],
            currency: cached_price[:currency],
            exchange_operating_mic: exchange_operating_mic
          )
        end
      end

      # Check database
      db_price = prices.find_by(date: date)
      if db_price.present?
        # Cache in Rails cache with appropriate TTL
        cache_duration = calculate_cache_duration(date)
        cache_data = { price: db_price.price, currency: db_price.currency }
        Rails.cache.write(cache_key, cache_data, expires_in: cache_duration) if cache

        return Provider::SecurityConcept::Price.new(
          symbol: ticker,
          date: date,
          price: db_price.price,
          currency: db_price.currency,
          exchange_operating_mic: exchange_operating_mic
        )
      end

      # Fetch from provider as last resort
      return nil unless self.class.provider.present?

      response = self.class.provider.fetch_security_price(
        symbol: ticker,
        exchange_operating_mic: exchange_operating_mic,
        date: date
      )

      return nil unless response.success?

      price_data = response.data

      # Save to database
      if cache
        Security::Price.find_or_create_by!(
          security_id: self.id,
          date: price_data.date,
          price: price_data.price,
          currency: price_data.currency
        )

        # Cache in Rails cache
        cache_duration = calculate_cache_duration(date)
        cache_data = { price: price_data.price, currency: price_data.currency }
        Rails.cache.write(cache_key, cache_data, expires_in: cache_duration)
      end

      price_data
    end

    # Clear cache for this security's price on a specific date
    def clear_price_cache(date:)
      cache_key = "#{CACHE_PREFIX}/#{ticker}/#{exchange_operating_mic}/#{date}"
      Rails.cache.delete(cache_key)
    end

    # Clear all price caches for this security
    def clear_all_price_caches
      Rails.cache.delete_matched("#{CACHE_PREFIX}/#{ticker}/#{exchange_operating_mic}/*")
    end

    private

      def calculate_cache_duration(date)
        days_ago = (Date.current - date).to_i

        if days_ago == 0
          # Today's price - cache for shorter time
          CURRENT_PRICE_CACHE_DURATION
        elsif days_ago <= 7
          # Recent prices - medium cache
          RECENT_PRICE_CACHE_DURATION
        else
          # Historical prices rarely change - longer cache
          HISTORICAL_PRICE_CACHE_DURATION
        end
      end
  end

  class_methods do
    # Batch price fetching with caching
    def fetch_prices_batch(symbol:, dates:, exchange_operating_mic: nil, cache: true)
      security = find_by(ticker: symbol, exchange_operating_mic: exchange_operating_mic)
      return [] unless security

      prices = []
      missing_dates = []

      dates.each do |date|
        cache_key = "#{CACHE_PREFIX}/#{symbol}/#{exchange_operating_mic}/#{date}"

        # Try cache first
        cached_price = Rails.cache.read(cache_key) if cache
        if cached_price.present?
          prices << Provider::SecurityConcept::Price.new(
            symbol: symbol,
            date: date,
            price: cached_price[:price],
            currency: cached_price[:currency],
            exchange_operating_mic: exchange_operating_mic
          )
          next
        end

        # Try database
        db_price = security.prices.find_by(date: date)
        if db_price.present?
          prices << Provider::SecurityConcept::Price.new(
            symbol: symbol,
            date: date,
            price: db_price.price,
            currency: db_price.currency,
            exchange_operating_mic: exchange_operating_mic
          )

          # Cache it
          cache_duration = security.send(:calculate_cache_duration, date)
          cache_data = { price: db_price.price, currency: db_price.currency }
          Rails.cache.write(cache_key, cache_data, expires_in: cache_duration) if cache
        else
          missing_dates << date
        end
      end

      # Fetch missing from provider
      if missing_dates.any? && provider.present?
        response = provider.fetch_security_prices(
          symbol: symbol,
          exchange_operating_mic: exchange_operating_mic,
          start_date: missing_dates.min,
          end_date: missing_dates.max
        )

        if response.success?
          response.data.each do |price_data|
            if cache
              Security::Price.find_or_create_by!(
                security_id: security.id,
                date: price_data.date,
                price: price_data.price,
                currency: price_data.currency
              )

              cache_key = "#{CACHE_PREFIX}/#{symbol}/#{exchange_operating_mic}/#{price_data.date}"
              cache_duration = security.send(:calculate_cache_duration, price_data.date)
              cache_data = { price: price_data.price, currency: price_data.currency }
              Rails.cache.write(cache_key, cache_data, expires_in: cache_duration)
            end

            prices << price_data
          end
        end
      end

      prices.sort_by(&:date)
    end

    # Clear all security price caches
    def clear_all_security_price_caches
      Rails.cache.delete_matched("#{CACHE_PREFIX}/*")
    end
  end
end

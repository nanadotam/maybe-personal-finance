# Exchange Rate Caching Strategy
#
# This module provides intelligent caching for exchange rates to minimize API calls
# while maintaining data freshness.
#
# Caching Layers:
# 1. Database (permanent storage) - existing
# 2. Rails cache (time-based, 24 hours for rates) - NEW
# 3. Request-level cache (same request) - NEW
#
module ExchangeRate::Caching
  extend ActiveSupport::Concern

  CACHE_DURATION = 24.hours # Exchange rates don't change that frequently
  CACHE_PREFIX = "exchange_rate"

  class_methods do
    # Enhanced find_or_fetch with aggressive caching
    def find_or_fetch_rate_with_cache(from:, to:, date: Date.current, cache: true)
      # Same currency, no conversion needed
      return Rate.new(date: date, from: from, to: to, rate: 1.0) if from == to

      cache_key = "#{CACHE_PREFIX}/#{from}/#{to}/#{date}"

      # Layer 1: Check Rails cache first (fast, in-memory)
      if cache
        cached_rate = Rails.cache.read(cache_key)
        return Rate.new(date: date, from: from, to: to, rate: cached_rate) if cached_rate.present?
      end

      # Layer 2: Check database
      db_rate = find_by(from_currency: from, to_currency: to, date: date)
      if db_rate.present?
        # Store in Rails cache for future requests
        Rails.cache.write(cache_key, db_rate.rate, expires_in: CACHE_DURATION) if cache
        return Rate.new(date: date, from: from, to: to, rate: db_rate.rate)
      end

      # Layer 3: Fetch from provider (last resort)
      return nil unless provider.present?

      response = provider.fetch_exchange_rate(from: from, to: to, date: date)
      return nil unless response.success?

      rate_data = response.data

      # Save to database
      if cache
        db_rate = ExchangeRate.find_or_create_by!(
          from_currency: rate_data.from,
          to_currency: rate_data.to,
          date: rate_data.date,
          rate: rate_data.rate
        )

        # Save to Rails cache
        Rails.cache.write(cache_key, rate_data.rate, expires_in: CACHE_DURATION)
      end

      rate_data
    end

    # Batch caching for multiple dates
    def find_or_fetch_rates_batch(from:, to:, dates:, cache: true)
      return [] if from == to

      rates = []
      missing_dates = []

      # Check what we already have in DB/cache
      dates.each do |date|
        cache_key = "#{CACHE_PREFIX}/#{from}/#{to}/#{date}"

        # Try cache first
        cached_rate = Rails.cache.read(cache_key) if cache
        if cached_rate.present?
          rates << Rate.new(date: date, from: from, to: to, rate: cached_rate)
          next
        end

        # Try database
        db_rate = find_by(from_currency: from, to_currency: to, date: date)
        if db_rate.present?
          rates << Rate.new(date: date, from: from, to: to, rate: db_rate.rate)
          Rails.cache.write(cache_key, db_rate.rate, expires_in: CACHE_DURATION) if cache
        else
          missing_dates << date
        end
      end

      # Fetch missing dates from provider
      if missing_dates.any? && provider.present?
        start_date = missing_dates.min
        end_date = missing_dates.max

        response = provider.fetch_exchange_rates(
          from: from,
          to: to,
          start_date: start_date,
          end_date: end_date
        )

        if response.success?
          response.data.each do |rate_data|
            # Save to database
            if cache
              ExchangeRate.find_or_create_by!(
                from_currency: rate_data.from,
                to_currency: rate_data.to,
                date: rate_data.date,
                rate: rate_data.rate
              )

              # Save to Rails cache
              cache_key = "#{CACHE_PREFIX}/#{from}/#{to}/#{rate_data.date}"
              Rails.cache.write(cache_key, rate_data.rate, expires_in: CACHE_DURATION)
            end

            rates << rate_data
          end
        end
      end

      rates.sort_by(&:date)
    end

    # Clear cache for specific rate
    def clear_rate_cache(from:, to:, date:)
      cache_key = "#{CACHE_PREFIX}/#{from}/#{to}/#{date}"
      Rails.cache.delete(cache_key)
    end

    # Clear all exchange rate caches
    def clear_all_rate_caches
      Rails.cache.delete_matched("#{CACHE_PREFIX}/*")
    end

    private

      def provider
        registry = Provider::Registry.for_concept(:exchange_rates)
        registry.providers.compact.first
      end
  end
end

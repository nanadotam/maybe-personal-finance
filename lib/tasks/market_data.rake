namespace :market_data do
  desc "Clear all market data caches (exchange rates and security prices)"
  task clear_cache: :environment do
    puts "Clearing all market data caches..."

    # Clear exchange rate caches
    ExchangeRate.clear_all_rate_caches
    puts "✓ Cleared exchange rate caches"

    # Clear security price caches
    Security.clear_all_security_price_caches
    puts "✓ Cleared security price caches"

    puts "Done! All market data caches have been cleared."
  end

  desc "Clear only exchange rate caches"
  task clear_exchange_rate_cache: :environment do
    puts "Clearing exchange rate caches..."
    ExchangeRate.clear_all_rate_caches
    puts "✓ Done!"
  end

  desc "Clear only security price caches"
  task clear_security_price_cache: :environment do
    puts "Clearing security price caches..."
    Security.clear_all_security_price_caches
    puts "✓ Done!"
  end

  desc "Show caching statistics"
  task cache_stats: :environment do
    puts "\n=== Market Data Cache Statistics ==="
    puts "\nExchange Rates:"
    puts "  - Database records: #{ExchangeRate.count}"
    puts "  - Cache strategy: 24-hour TTL"
    puts "  - Provider: #{ExchangeRate.provider&.class&.name || 'Not configured'}"

    puts "\nSecurity Prices:"
    puts "  - Database records: #{Security::Price.count}"
    puts "  - Securities tracked: #{Security.count}"
    puts "  - Cache strategy: 15min (current), 1hour (recent), 24hour (historical)"
    puts "  - Provider: #{Security.provider&.class&.name || 'Not configured'}"

    if Rails.cache.respond_to?(:stats)
      puts "\nCache Store Stats:"
      puts Rails.cache.stats.inspect
    end

    puts "\n"
  end

  desc "Warm up cache with frequently used exchange rates"
  task warm_cache: :environment do
    puts "Warming up market data cache..."

    # Find commonly used currency pairs from accounts
    currency_pairs = Account.pluck(:currency).uniq.flat_map do |from_currency|
      Family.pluck(:currency).uniq.map do |to_currency|
        [ from_currency, to_currency ] if from_currency != to_currency
      end
    end.compact.uniq

    puts "Found #{currency_pairs.length} currency pairs to cache"

    # Cache recent rates for each pair
    currency_pairs.each do |from, to|
      print "."
      ExchangeRate.find_or_fetch_rate_with_cache(from: from, to: to, date: Date.current)
    rescue => e
      puts "\nError caching #{from}/#{to}: #{e.message}"
    end

    puts "\n✓ Cache warmed up!"
  end

  desc "Monitor API usage (check how many calls we're making)"
  task monitor_usage: :environment do
    puts "\n=== API Usage Monitoring ==="

    # Check exchange rate provider
    exchange_provider = ExchangeRate.provider
    if exchange_provider
      puts "\nExchange Rate Provider: #{exchange_provider.class.name}"
      usage = exchange_provider.usage
      if usage&.success?
        puts "  - Used: #{usage.data.used}"
        puts "  - Limit: #{usage.data.limit}"
        puts "  - Utilization: #{usage.data.utilization.round(2)}%"
        puts "  - Plan: #{usage.data.plan}"
      else
        puts "  - Could not fetch usage stats"
      end
    else
      puts "\nExchange Rate Provider: Not configured"
    end

    # Check security provider
    security_provider = Security.provider
    if security_provider
      puts "\nSecurity Provider: #{security_provider.class.name}"
      usage = security_provider.usage
      if usage&.success?
        puts "  - Used: #{usage.data.used}"
        puts "  - Limit: #{usage.data.limit}"
        puts "  - Utilization: #{usage.data.utilization.round(2)}%"
        puts "  - Plan: #{usage.data.plan}"
      else
        puts "  - Could not fetch usage stats"
      end
    else
      puts "\nSecurity Provider: Not configured"
    end

    puts "\n"
  end
end

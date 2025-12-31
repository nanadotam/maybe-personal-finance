class Provider::ExchangerateApi < Provider
  include ExchangeRateConcept

  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)

  def initialize(api_key = nil)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      # Test with a simple latest rates call
      response = client.get("#{base_url}/latest/USD")
      JSON.parse(response.body).dig("result") == "success"
    end
  end

  def usage
    # Exchangerate-API doesn't provide usage stats in free tier
    # Return a basic structure
    with_provider_response do
      UsageData.new(
        used: 0,
        limit: 1500, # Free tier limit per month
        utilization: 0,
        plan: "Free Tier"
      )
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      # Use historical endpoint if we have an API key, otherwise use latest
      if date == Date.current || date == Date.today
        response = client.get("#{base_url}/latest/#{from}")
      else
        # Historical data requires paid plan
        response = client.get("#{base_url}/history/#{from}/#{date.year}/#{date.month}/#{date.day}")
      end

      parsed = JSON.parse(response.body)

      if parsed["result"] != "success"
        raise InvalidExchangeRateError, "API returned error: #{parsed['error-type']}"
      end

      rate_value = parsed.dig("conversion_rates", to)

      if rate_value.nil?
        raise InvalidExchangeRateError, "No rate found for #{from} to #{to}"
      end

      Rate.new(date: date.to_date, from:, to:, rate: rate_value)
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      rates = []

      # For free tier, we can only get latest rates
      # For historical, we'd need to make individual calls (paid tier)
      if start_date > Date.current - 7.days
        # Recent data - fetch latest
        response = client.get("#{base_url}/latest/#{from}")
        parsed = JSON.parse(response.body)

        if parsed["result"] == "success"
          rate_value = parsed.dig("conversion_rates", to)

          if rate_value.present?
            # Return the same rate for all dates in range (approximation)
            current_date = start_date
            while current_date <= end_date && current_date <= Date.current
              rates << Rate.new(date: current_date, from:, to:, rate: rate_value)
              current_date += 1.day
            end
          end
        end
      else
        # Historical data - need to fetch day by day for paid tier
        # For free tier, log warning and return empty
        Rails.logger.warn("ExchangerateApi: Historical data beyond 7 days requires paid plan. Requested: #{start_date} to #{end_date}")
      end

      rates
    end
  end

  private
    attr_reader :api_key

    def base_url
      if api_key.present?
        "https://v6.exchangerate-api.com/v6/#{api_key}"
      else
        # Fallback to a free, no-auth service
        ENV["EXCHANGERATE_URL"] || "https://api.exchangerate-api.com/v4"
      end
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.response :raise_error
        # No authentication header needed - API key is in URL
      end
    end
end

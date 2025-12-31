class Provider::FinancialModelingPrep < Provider
  include SecurityConcept

  Error = Class.new(Provider::Error)
  InvalidSecurityPriceError = Class.new(Error)

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      response = client.get("#{base_url}/v3/profile/AAPL") do |req|
        req.params["apikey"] = api_key
      end
      parsed = JSON.parse(response.body)
      parsed.is_a?(Array) && parsed.any?
    end
  end

  def usage
    # FMP doesn't provide usage stats easily
    # Return a basic structure
    with_provider_response do
      UsageData.new(
        used: 0,
        limit: 250, # Free tier limit per day
        utilization: 0,
        plan: "Free Tier"
      )
    end
  end

  # ================================
  #           Securities
  # ================================

  def search_securities(symbol, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      response = client.get("#{base_url}/v3/search") do |req|
        req.params["query"] = symbol
        req.params["limit"] = 25
        req.params["apikey"] = api_key
        req.params["exchange"] = exchange_operating_mic if exchange_operating_mic.present?
      end

      parsed = JSON.parse(response.body)

      return [] unless parsed.is_a?(Array)

      parsed.map do |security|
        # Filter by country if specified
        next if country_code.present? && security["exchangeShortName"]&.exclude?(country_code)

        Security.new(
          symbol: security["symbol"],
          name: security["name"],
          logo_url: nil, # FMP doesn't provide logos in search
          exchange_operating_mic: security["exchangeShortName"],
          country_code: security["currency"]
        )
      end.compact
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic: nil)
    with_provider_response do
      response = client.get("#{base_url}/v3/profile/#{symbol}") do |req|
        req.params["apikey"] = api_key
      end

      data = JSON.parse(response.body)
      return nil unless data.is_a?(Array) && data.any?

      security_data = data.first

      SecurityInfo.new(
        symbol: symbol,
        name: security_data["companyName"],
        links: {
          "website" => security_data["website"]
        }.compact,
        logo_url: security_data["image"],
        description: security_data["description"],
        kind: security_data["isEtf"] ? "etf" : "stock",
        exchange_operating_mic: security_data["exchangeShortName"]
      )
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic: nil, date:)
    with_provider_response do
      # For today's date, use quote endpoint
      if date >= Date.current
        response = client.get("#{base_url}/v3/quote/#{symbol}") do |req|
          req.params["apikey"] = api_key
        end

        data = JSON.parse(response.body)
        return nil unless data.is_a?(Array) && data.any?

        quote = data.first

        Price.new(
          symbol: symbol,
          date: Date.current,
          price: quote["price"],
          currency: "USD", # FMP primarily uses USD
          exchange_operating_mic: exchange_operating_mic
        )
      else
        # Use historical data
        historical_data = fetch_security_prices(
          symbol: symbol,
          exchange_operating_mic: exchange_operating_mic,
          start_date: date,
          end_date: date
        )

        historical_data.data.first
      end
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic: nil, start_date:, end_date:)
    with_provider_response do
      response = client.get("#{base_url}/v3/historical-price-full/#{symbol}") do |req|
        req.params["from"] = start_date.to_s
        req.params["to"] = end_date.to_s
        req.params["apikey"] = api_key
      end

      data = JSON.parse(response.body)

      historical = data.dig("historical") || []

      prices = historical.map do |price_data|
        date = price_data["date"]
        close_price = price_data["close"]
        open_price = price_data["open"]

        if date.nil? || (close_price.nil? && open_price.nil?)
          Rails.logger.warn("#{self.class.name} returned invalid price data for security #{symbol} on: #{date}")
          Sentry.capture_exception(InvalidSecurityPriceError.new("#{self.class.name} returned invalid security price data"), level: :warning) do |scope|
            scope.set_context("security", { symbol: symbol, date: date })
          end

          next
        end

        Price.new(
          symbol: symbol,
          date: date.to_date,
          price: close_price || open_price,
          currency: "USD", # FMP primarily uses USD
          exchange_operating_mic: exchange_operating_mic || data["symbol"]
        )
      end.compact

      # Return in a format compatible with the existing interface
      PaginatedData.new(
        paginated: prices,
        first_page: { "currency" => "USD", "exchange" => { "operating_mic_code" => exchange_operating_mic } },
        total_pages: 1
      )
    end
  end

  private
    attr_reader :api_key

    def base_url
      ENV["FMP_URL"] || "https://financialmodelingprep.com/api"
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
      end
    end
end

class Assistant::Function::GetBalanceSheet < Assistant::Function
  include ActiveSupport::NumberHelper

  class << self
    def name
      "get_balance_sheet"
    end

    def description
      <<~INSTRUCTIONS
        Use this to get the user's balance sheet with varying amounts of historical data.

        Use detail_level to control how much data is returned:
        - "summary": current totals only (lowest token usage)
        - "standard": 6 months of net worth history (default)
        - "detailed": 1 year of history for net worth, assets, and liabilities

        This is great for answering questions like:
        - What is the user's net worth? What is it composed of?
        - How has the user's wealth changed over time?
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      properties: {
        detail_level: {
          type: "string",
          enum: %w[summary standard detailed],
          description: "Controls how much historical data to return. Default: summary"
        }
      }
    )
  end

  def call(params = {})
    level = params.fetch("detail_level", "summary")

    result = {
      as_of_date: Date.current,
      currency: family.currency,
      net_worth: { current: family.balance_sheet.net_worth_money.format },
      assets: { current: family.balance_sheet.assets.total_money.format },
      liabilities: { current: family.balance_sheet.liabilities.total_money.format },
      insights: insights_data
    }

    unless level == "summary"
      lookback = level == "detailed" ? 1.year : 6.months
      observation_start_date = [ lookback.ago.to_date, family.oldest_entry_date ].max
      period = Period.custom(start_date: observation_start_date, end_date: Date.current)

      result[:net_worth][:monthly_history] = historical_data(period)

      if level == "detailed"
        result[:assets][:monthly_history] = historical_data(period, classification: "asset")
        result[:liabilities][:monthly_history] = historical_data(period, classification: "liability")
      end
    end

    result
  end

  private
    def historical_data(period, classification: nil)
      scope = family.accounts.visible
      scope = scope.where(classification: classification) if classification.present?

      if period.start_date == Date.current
        []
      else
        account_ids = scope.pluck(:id)

        builder = Balance::ChartSeriesBuilder.new(
          account_ids: account_ids,
          currency: family.currency,
          period: period,
          favorable_direction: "up",
          interval: "1 month"
        )

        to_ai_time_series(builder.balance_series)
      end
    end

    def insights_data
      assets = family.balance_sheet.assets.total
      liabilities = family.balance_sheet.liabilities.total
      ratio = liabilities.zero? ? 0 : (liabilities / assets.to_f)

      {
        debt_to_asset_ratio: number_to_percentage(ratio * 100, precision: 0)
      }
    end
end

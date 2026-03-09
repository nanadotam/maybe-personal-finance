class Assistant::Function::GetAccounts < Assistant::Function
  class << self
    def name
      "get_accounts"
    end

    def description
      <<~DESC
        Use this to see what accounts the user has along with their current and historical balances.

        Use detail_level to control how much data is returned:
        - "summary": current balances only (lowest token usage)
        - "standard": 3 months of monthly history (default)
        - "detailed": 1 year of monthly history
      DESC
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

    {
      as_of_date: Date.current,
      accounts: family.accounts.visible.includes(:balances).map do |account|
        account_data = {
          name: account.name,
          balance_formatted: account.balance_money.format,
          classification: account.classification,
          type: account.accountable_type,
          status: account.status
        }

        account_data[:historical_balances] = historical_balances(account, level) unless level == "summary"
        account_data
      end
    }
  end

  private
    def historical_balances(account, level)
      lookback = level == "detailed" ? 1.year : 3.months
      start_date = [ account.start_date, lookback.ago.to_date ].max
      period = Period.custom(start_date: start_date, end_date: Date.current)
      balance_series = account.balance_series(period: period, interval: "1 month")

      to_ai_time_series(balance_series)
    end
end

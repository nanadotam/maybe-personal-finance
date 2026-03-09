class Assistant::Function::GetSpendingTrends < Assistant::Function
  include ActiveSupport::NumberHelper

  class << self
    def name
      "get_spending_trends"
    end

    def description
      "Compare spending or income across months with optional category filter."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      properties: {
        months: { type: "integer", description: "1-12, default 3" },
        category_name: { type: "string", enum: family_category_names },
        type: { type: "string", enum: %w[expense income both] }
      }
    )
  end

  def call(params = {})
    months = [ params.fetch("months", 3).to_i, 12 ].min
    category = resolve_category(params["category_name"])
    show_type = params.fetch("type", "expense")

    monthly_data = (0...months).map do |i|
      start_date = i.months.ago.beginning_of_month.to_date
      end_date = i.months.ago.end_of_month.to_date
      period = Period.custom(start_date: start_date, end_date: end_date)

      month_result = { month: start_date.strftime("%B %Y") }

      if %w[expense both].include?(show_type)
        expense_data = family.income_statement.expense_totals(period: period)
        month_result[:expenses] = if category
          cat_total = expense_data.category_totals.find { |ct| ct.category.id == category.id }
          format_money(cat_total&.total || 0)
        else
          format_money(expense_data.total)
        end
      end

      if %w[income both].include?(show_type)
        income_data = family.income_statement.income_totals(period: period)
        month_result[:income] = format_money(income_data.total)
      end

      month_result
    end.reverse

    result = {
      currency: family.currency,
      period: "#{months} months (#{monthly_data.first&.dig(:month)} to #{monthly_data.last&.dig(:month)})",
      monthly_breakdown: monthly_data
    }

    if category
      result[:category] = category.name
    end

    result
  end

  private
    def format_money(value)
      Money.new(value, family.currency).format
    end

    def resolve_category(name)
      return nil if name.blank? || name == "Uncategorized"
      family.categories.find_by(name: name)
    end
end

class Assistant::Function::GetIncomeStatement < Assistant::Function
  include ActiveSupport::NumberHelper

  class << self
    def name
      "get_income_statement"
    end

    def description
      "Get income/expense breakdown by category for a date range. detail_level controls category depth."
    end
  end

  def strict_mode?
    false
  end

  def call(params = {})
    level = params.fetch("detail_level", "summary")
    period = Period.custom(start_date: Date.parse(params["start_date"]), end_date: Date.parse(params["end_date"]))
    income_data = family.income_statement.income_totals(period: period)
    expense_data = family.income_statement.expense_totals(period: period)

    {
      currency: family.currency,
      period: {
        start_date: period.start_date,
        end_date: period.end_date
      },
      income: {
        total: format_money(income_data.total),
        by_category: to_ai_category_totals(income_data.category_totals, level)
      },
      expense: {
        total: format_money(expense_data.total),
        by_category: to_ai_category_totals(expense_data.category_totals, level)
      },
      insights: get_insights(income_data, expense_data)
    }
  end

  def params_schema
    build_schema(
      required: [ "start_date", "end_date" ],
      properties: {
        start_date: { type: "string", description: "YYYY-MM-DD" },
        end_date: { type: "string", description: "YYYY-MM-DD" },
        detail_level: { type: "string", enum: %w[summary standard detailed] }
      }
    )
  end

  private
    def format_money(value)
      Money.new(value, family.currency).format
    end

    def calculate_savings_rate(total_income, total_expenses)
      return 0 if total_income.zero?
      savings = total_income - total_expenses
      rate = (savings / total_income.to_f) * 100
      rate.round(2)
    end

    def to_ai_category_totals(category_totals, level)
      hierarchical_groups = category_totals.group_by { |ct| ct.category.parent_id }.then do |grouped|
        root_category_totals = grouped[nil] || []

        root_category_totals.each_with_object({}) do |ct, hash|
          subcategory_totals = ct.category.name == "Uncategorized" ? [] : (grouped[ct.category.id] || [])
          hash[ct.category.name] = {
            category_total: ct,
            subcategory_totals: subcategory_totals
          }
        end
      end

      sorted = hierarchical_groups.sort_by { |name, data| -data.dig(:category_total).total }

      # Limit to top 5 categories for summary
      sorted = sorted.first(5) if level == "summary"

      sorted.map do |name, data|
        entry = {
          name: name,
          total: format_money(data.dig(:category_total).total),
          percentage_of_total: number_to_percentage(data.dig(:category_total).weight, precision: 1)
        }

        # Only include subcategories for detailed level
        if level == "detailed"
          entry[:subcategory_totals] = data.dig(:subcategory_totals).map do |st|
            {
              name: st.category.name,
              total: format_money(st.total),
              percentage_of_total: number_to_percentage(st.weight, precision: 1)
            }
          end
        end

        entry
      end
    end

    def get_insights(income_data, expense_data)
      net_income = income_data.total - expense_data.total
      savings_rate = calculate_savings_rate(income_data.total, expense_data.total)

      {
        net_income: format_money(net_income),
        savings_rate: number_to_percentage(savings_rate)
      }
    end
end

class PortfoliosController < ApplicationController
  RANGES = {
    "1m" => { months: 1,  label: "1 Month" },
    "3m" => { months: 3,  label: "3 Months" },
    "6m" => { months: 6,  label: "6 Months" },
    "1y" => { months: 12, label: "1 Year" }
  }.freeze

  def show
    @rule = Current.family.budget_split_rule
    return unless @rule

    @range_key = RANGES.key?(params[:range]) ? params[:range] : "1m"
    @ranges = RANGES
    months = RANGES[@range_key][:months]

    @period = Period.custom(
      start_date: (Date.current - (months - 1).months).beginning_of_month,
      end_date: Date.current.end_of_month
    )
    @monthly_income = (params[:monthly_income].presence || default_monthly_income).to_d
    @dashboard = @rule.dashboard_for(@period, monthly_income: @monthly_income, months: months)
  end

  private
    # Falls back to the family's actual median monthly income (native to Maybe)
    # when no ?monthly_income= override is given, so the dashboard is useful even
    # before you manually confirm a figure (see PRD open question — income varies
    # month to month with the side business).
    def default_monthly_income
      Current.family.income_statement.median_income(interval: "month").presence || 7500
    end
end

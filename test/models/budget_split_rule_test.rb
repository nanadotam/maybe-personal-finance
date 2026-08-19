require "test_helper"

class BudgetSplitRuleTest < ActiveSupport::TestCase
  setup do
    @rule = budget_split_rules(:one)
  end

  test "valid when tithe + needs + wants + savings sum to 100" do
    assert @rule.valid?
  end

  test "invalid when percentages do not sum to 100" do
    @rule.savings_percent = 50.0
    assert_not @rule.valid?
    assert_includes @rule.errors[:base].join, "must sum to 100"
  end

  test "actual_percent_for sums allocations in a bucket" do
    assert_equal 16.67, @rule.actual_percent_for("savings")
  end

  test "variance_for compares actual allocation to target bucket percent" do
    # savings target is 20%, only Databank (16.67%) is allocated to savings in fixtures
    assert_in_delta(-3.33, @rule.variance_for("savings"), 0.01)
  end

  test "seed_ghs_default_for creates rule and 11 allocations summing to 100 percent" do
    family = families(:empty)

    rule = BudgetSplitRule.seed_ghs_default_for(family)

    assert_equal 11, rule.budget_split_allocations.count
    assert_in_delta 100.0, rule.total_allocated_percent, 0.01
  end

  test "seed_ghs_default_for creates 5 real accounts (Databank/Achieve as investments) and 6 categories" do
    family = families(:empty)

    BudgetSplitRule.seed_ghs_default_for(family)

    assert_equal 5, family.accounts.where(name: [ "Databank", "Zenith", "Achieve", "EcoBank Savings", "EcoBank Current" ]).count
    assert_kind_of Investment, family.accounts.find_by(name: "Databank").accountable
    assert_kind_of Investment, family.accounts.find_by(name: "Achieve").accountable
    assert_kind_of Depository, family.accounts.find_by(name: "Zenith").accountable

    assert_equal 6, family.categories.where(
      name: [ "Tithe", "Enjoyment", "Offertory", "Airtime & Data", "Subscriptions", "Miscellaneous" ]
    ).count
  end

  test "seed_ghs_default_for is idempotent — re-running does not duplicate accounts" do
    family = families(:empty)
    account_names = [ "Databank", "Zenith", "Achieve", "EcoBank Savings", "EcoBank Current" ]

    BudgetSplitRule.seed_ghs_default_for(family)
    BudgetSplitRule.seed_ghs_default_for(family)

    assert_equal 5, family.accounts.where(name: account_names).count
  end

  test "amount_for computes a bucket allocation amount from monthly income" do
    allocation = budget_split_allocations(:databank)
    assert_equal 1250.25.to_d, allocation.amount_for(7500)
  end

  test "dashboard_for scales target amounts by months but not actuals" do
    family = families(:empty)
    rule = BudgetSplitRule.seed_ghs_default_for(family)
    period = Period.custom(start_date: 6.months.ago.to_date, end_date: Date.current)

    one_month = rule.dashboard_for(period, monthly_income: 7500, months: 1)
    six_months = rule.dashboard_for(period, monthly_income: 7500, months: 6)

    assert_equal one_month[:buckets]["tithe"][:target_amount] * 6, six_months[:buckets]["tithe"][:target_amount]
    assert_equal 0, six_months[:buckets]["tithe"][:actual_amount]
  end
end

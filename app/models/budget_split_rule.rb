class BudgetSplitRule < ApplicationRecord
  belongs_to :family

  has_many :budget_split_allocations, dependent: :destroy

  BUCKETS = %w[tithe needs wants savings].freeze

  # Each entry either creates/links a real Maybe account (for the 5 accounts you
  # actually hold — investments get real Holdings/Trades-backed growth tracking,
  # depository accounts get real balance tracking) or a category (for line items
  # that aren't a dedicated account, e.g. Tithe, Airtime, Subscriptions).
  GHS_DEFAULT_ALLOCATIONS = [
    { name: "Tithe — God",     bucket: "tithe",   percent: 10.00, category_name: "Tithe" },
    { name: "Databank",        bucket: "savings", percent: 16.67, account_name: "Databank", accountable_type: "Investment", subtype: "mutual_fund" },
    { name: "Zenith",          bucket: "savings", percent: 8.33,  account_name: "Zenith", accountable_type: "Depository", subtype: "savings" },
    { name: "Achieve",         bucket: "savings", percent: 8.33,  account_name: "Achieve", accountable_type: "Investment", subtype: "brokerage" },
    { name: "EcoBank Savings", bucket: "savings", percent: 16.67, account_name: "EcoBank Savings", accountable_type: "Depository", subtype: "savings" },
    { name: "EcoBank Current", bucket: "needs",   percent: 16.67, account_name: "EcoBank Current", accountable_type: "Depository", subtype: "checking" },
    { name: "Enjoyment",       bucket: "wants",   percent: 10.00, category_name: "Enjoyment" },
    { name: "Offertory",       bucket: "tithe",   percent: 2.13,  category_name: "Offertory" },
    { name: "Airtime",         bucket: "needs",   percent: 0.67,  category_name: "Airtime & Data" },
    { name: "Subscriptions",   bucket: "needs",   percent: 5.33,  category_name: "Subscriptions" },
    { name: "Miscellaneous",   bucket: "wants",   percent: 5.20,  category_name: "Miscellaneous" }
  ].freeze

  validates :tithe_percent, :needs_percent, :wants_percent, :savings_percent,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :percents_sum_to_100

  def target_percent_for(bucket)
    public_send("#{bucket}_percent")
  end

  def allocations_for(bucket)
    budget_split_allocations.where(bucket: bucket)
  end

  def actual_percent_for(bucket)
    allocations_for(bucket).sum(:percent)
  end

  def variance_for(bucket)
    actual_percent_for(bucket) - target_percent_for(bucket)
  end

  def total_allocated_percent
    budget_split_allocations.sum(:percent)
  end

  def amounts_for(monthly_income)
    budget_split_allocations.order(:bucket, :name).map do |allocation|
      {
        name: allocation.name,
        bucket: allocation.bucket,
        percent: allocation.percent,
        amount: allocation.amount_for(monthly_income)
      }
    end
  end

  # Live dashboard data for a period: per-bucket target vs. actual, plus
  # whatever family spend/income isn't claimed by any allocation ("Unclassified").
  # Nothing here is written/cached — always reflects current transactions.
  def dashboard_for(period, monthly_income:)
    buckets = BUCKETS.index_with do |bucket|
      allocations = allocations_for(bucket).order(:name).map do |allocation|
        {
          name: allocation.name,
          target_amount: allocation.amount_for(monthly_income),
          actual_amount: allocation.actual_amount_for(period)
        }
      end

      {
        target_percent: target_percent_for(bucket),
        actual_percent: actual_percent_for(bucket),
        target_amount: monthly_income.to_d * target_percent_for(bucket).to_d / 100,
        actual_amount: allocations.sum { |a| a[:actual_amount] },
        allocations: allocations
      }
    end

    { buckets: buckets, unclassified_amount: unclassified_amount(period) }
  end

  # Standard (non-transfer) family spend in the period that isn't claimed by
  # any account- or category-linked allocation. Shown for review, never blocks anything.
  def unclassified_amount(period)
    claimed_account_ids = budget_split_allocations.where.not(account_id: nil).pluck(:account_id)
    claimed_category_ids = budget_split_allocations.where.not(category_id: nil).pluck(:category_id)

    family.transactions.visible.in_period(period).standard
      .joins(:entry)
      .where.not(entry: { account_id: claimed_account_ids })
      .where.not(category_id: claimed_category_ids)
      .sum("entries.amount")
  end

  # Seeds the personal Ghana-cedi budget split (tithe/needs/wants/savings + 11 named
  # allocations, each linked to a real account or category) for the given family,
  # replacing any existing rule/allocations. Idempotent — safe to re-run.
  def self.seed_ghs_default_for(family)
    transaction do
      rule = find_or_initialize_by(family: family)
      rule.assign_attributes(
        tithe_percent: 10.0,
        needs_percent: 50.0,
        wants_percent: 20.0,
        savings_percent: 20.0
      )
      rule.save!

      rule.budget_split_allocations.destroy_all

      GHS_DEFAULT_ALLOCATIONS.each_with_index do |attrs, i|
        attrs = attrs.dup
        account_name = attrs.delete(:account_name)
        accountable_type = attrs.delete(:accountable_type)
        subtype = attrs.delete(:subtype)
        category_name = attrs.delete(:category_name)

        if account_name
          account = family.accounts.find_or_create_by!(name: account_name) do |a|
            a.accountable = accountable_type.constantize.new
            a.subtype = subtype
            a.status = "active"
            a.currency = "GHS"
            a.balance = 0
          end
          attrs[:account] = account
        end

        if category_name
          category = family.categories.find_or_create_by!(name: category_name) do |c|
            c.classification = "expense"
            c.color = Category::COLORS[i % Category::COLORS.length]
            c.lucide_icon = "circle"
          end
          attrs[:category] = category
        end

        rule.budget_split_allocations.create!(attrs)
      end

      rule
    end
  end

  private
    def percents_sum_to_100
      sum = [ tithe_percent, needs_percent, wants_percent, savings_percent ].compact.sum
      unless sum.zero? || (sum - 100).abs < 0.01
        errors.add(:base, "Tithe + Needs + Wants + Savings percentages must sum to 100 (currently #{sum})")
      end
    end
end

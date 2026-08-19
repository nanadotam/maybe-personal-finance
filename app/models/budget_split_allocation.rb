class BudgetSplitAllocation < ApplicationRecord
  belongs_to :budget_split_rule
  belongs_to :account, optional: true
  belongs_to :category, optional: true

  has_one :family, through: :budget_split_rule

  validates :name, presence: true
  validates :bucket, inclusion: { in: BudgetSplitRule::BUCKETS }
  validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def amount_for(monthly_income)
    (monthly_income.to_d * percent.to_d / 100).round(2)
  end

  # Live-computed actual spend/contribution for this allocation over a period.
  # No write-time classification, no backfill needed — always reflects current data.
  #
  # - "savings" bucket allocations (Databank, Zenith, Achieve, EcoBank Savings): the
  #   account is a real Maybe account, so "actual" = net internal transfers INTO it
  #   this period (funds_movement entries with a negative/inflow amount).
  # - Everything else: real spend (kind: "standard") on the linked account and/or category.
  def actual_amount_for(period)
    return 0.to_d unless account.present? || category.present?

    if bucket == "savings" && account.present?
      contribution_amount(period)
    else
      spend_amount(period)
    end
  end

  private
    def base_scope(period)
      family.transactions.visible.in_period(period)
    end

    def contribution_amount(period)
      base_scope(period)
        .funds_movement
        .joins(:entry)
        .where(entry: { account_id: account_id })
        .where("entries.amount < 0")
        .sum("entries.amount")
        .abs
    end

    def spend_amount(period)
      scope = base_scope(period).standard

      scope = scope.joins(:entry).where(entry: { account_id: account_id }) if account.present?
      scope = scope.where(category_id: category_id) if category.present?

      scope.sum("entries.amount")
    end
end

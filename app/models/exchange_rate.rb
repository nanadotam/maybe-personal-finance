class ExchangeRate < ApplicationRecord
  include Provided
  include Caching

  validates :from_currency, :to_currency, :date, :rate, presence: true
  validates :date, uniqueness: { scope: %i[from_currency to_currency] }
end

class ExchangeRate < ApplicationRecord
  include Provided
<<<<<<< HEAD
=======
  include Caching
>>>>>>> 6b5cab33 (Initial commit)

  validates :from_currency, :to_currency, :date, :rate, presence: true
  validates :date, uniqueness: { scope: %i[from_currency to_currency] }
end

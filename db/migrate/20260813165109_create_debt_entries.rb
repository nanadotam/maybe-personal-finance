class CreateDebtEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :debt_entries, id: :uuid do |t|
      t.references :debt, null: false, foreign_key: true, type: :uuid
      # Positive amount increases what the counterparty owes the family (new charge/shared expense).
      # Negative amount decreases it (a repayment).
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.date :occurred_on, null: false
      t.string :note

      t.timestamps
    end
  end
end

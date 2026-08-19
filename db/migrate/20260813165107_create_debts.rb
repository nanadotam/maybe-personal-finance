class CreateDebts < ActiveRecord::Migration[7.2]
  def change
    create_table :debts, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :counterparty_name, null: false
      t.string :currency, null: false
      t.text :notes

      t.timestamps
    end
  end
end

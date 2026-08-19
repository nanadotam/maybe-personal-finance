class CreateBudgetSplitRules < ActiveRecord::Migration[7.2]
  def change
    create_table :budget_split_rules, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid, index: false
      t.decimal :tithe_percent, precision: 5, scale: 2, null: false, default: 10.0
      t.decimal :needs_percent, precision: 5, scale: 2, null: false, default: 50.0
      t.decimal :wants_percent, precision: 5, scale: 2, null: false, default: 20.0
      t.decimal :savings_percent, precision: 5, scale: 2, null: false, default: 20.0

      t.timestamps
    end

    add_index :budget_split_rules, :family_id, unique: true
  end
end

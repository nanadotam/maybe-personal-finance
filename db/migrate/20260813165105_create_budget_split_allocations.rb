class CreateBudgetSplitAllocations < ActiveRecord::Migration[7.2]
  def change
    create_table :budget_split_allocations, id: :uuid do |t|
      t.references :budget_split_rule, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :bucket, null: false # tithe | needs | wants | savings
      t.decimal :percent, precision: 5, scale: 2, null: false
      t.references :account, null: true, foreign_key: true, type: :uuid
      t.references :category, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :budget_split_allocations, [ :budget_split_rule_id, :bucket ]
  end
end

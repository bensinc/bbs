class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
    	t.column :username, :string
    	t.column :level, :integer, default: 0
      t.timestamps
    end
  end
end

class CreateMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :messages do |t|

    	t.column :subject, :string
    	t.column :body, :text
    	t.column :user_id, :integer
    	t.column :message_id, :integer
      t.timestamps
    end
  end
end

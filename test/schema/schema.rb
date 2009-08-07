ActiveRecord::Schema.define do
  create_table :entrants, :force => true do |t|
    t.string  :name, :null => false
    t.integer :course_id, :null => false
  end
  
  create_table :courses, :force => true do |t|
    t.column :name, :string, :null => false
  end
end

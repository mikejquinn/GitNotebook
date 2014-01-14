Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :email, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      index :email, unique: true
    end

    create_table(:projects) do
      primary_key :id
      foreign_key :creator_id, :users, null: false
      String :name, null: false
      String :string_id, null: false # Random alpha-numeric string e.g. 'a83c02zo'
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      index :string_id, unique: true
    end

    create_table(:users_projects) do
      foreign_key :user_id, :users, null: false
      foreign_key :project_id, :projects, null: false
      index [:user_id, :project_id], unique: true
    end
  end
end

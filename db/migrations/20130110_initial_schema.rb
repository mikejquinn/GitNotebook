Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :email, null: false

      index :email, unique: true
    end
  end
end

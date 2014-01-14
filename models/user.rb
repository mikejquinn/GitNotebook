class User < Sequel::Model
  many_to_many :projects, join_table: :users_projects
end

require "sequel"

DB=Sequel.connect(adapter: "mysql2",
                  database: DB_NAME,
                  host: DB_HOST,
                  password: DB_PASSWORD,
                  user: DB_USER)

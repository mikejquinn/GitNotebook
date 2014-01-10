#!/usr/bin/env ruby

require "sequel"

Sequel.extension :migration

require "./environment"
require "./lib/db"

Sequel::Migrator.run(DB, "./db/migrations")

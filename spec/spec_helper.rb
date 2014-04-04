require_relative '../lib/queue_classic_admin.rb'

require 'capybara'
require 'capybara/rspec'

Capybara.app = QueueClassic::Admin

RSpec.configure do |config|
  config.before do
    execute_sql "DELETE FROM queue_classic_jobs"
  end
end

def execute_sql(sql, params = [])
  QC.default_conn_adapter.connection.exec(sql, params).to_a
end

execute_sql "DROP TABLE IF EXISTS queue_classic_jobs CASCADE"
execute_sql "DROP TABLE IF EXISTS queue_classic_later_jobs CASCADE"

execute_sql <<-SQL
  CREATE TABLE queue_classic_jobs (
    id bigserial PRIMARY KEY,
    q_name text not null check (length(q_name) > 0),
    method text not null check (length(method) > 0),
    args   text not null,
    locked_at timestamptz,
    locked_by integer,
    created_at timestamptz default now()
  );
SQL

execute_sql "CREATE TABLE queue_classic_later_jobs (q_name varchar(255), method varchar(255), args text, not_before timestamptz);"


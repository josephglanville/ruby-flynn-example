require 'socket'
require 'sinatra'
require 'pg'
require 'redis'
require 'uri'

$stdout.sync = true

if ENV['PGHOST']
  $pg = PG::Connection.open host: ENV['PGHOST'],
                            user: ENV['PGUSER'],
                            password: ENV['PGPASSWORD'],
                            port: 5432,
                            dbname: ENV['PGDATABASE']

  $pg.exec <<-EOF
    CREATE TABLE IF NOT EXISTS counters (
      name text PRIMARY KEY,
      counter int NOT NULL
    );
  EOF
  $pg.exec <<-EOF
    INSERT INTO counters (name, counter)
    SELECT 'visitor_counter', 0
    WHERE NOT EXISTS (SELECT name FROM counters WHERE name = 'visitor_counter');
  EOF
end

$redis = Redis.new if ENV['REDIS_URL']

get '/' do
  @pg_status = "Postgres not yet configured, you can add a database with `flynn resource add postgres`"
  if ENV['PGHOST']
    $pg.exec("UPDATE counters SET counter = counter + 1 WHERE name = 'visitor_counter' RETURNING counter;") do |result|
      result.each do |row|
        @pg_status = "Postgres visitor counter: %d" % row.values_at('counter')
      end
    end
  end
  @redis_status = 'Redis not yet configured, you can add a redis instance with `flynn resource add redis`'
  if ENV['REDIS_URL']
    cur = $redis.incr("visitor_counter")
    @redis_status = "Redis visitor counter: %d" % cur
  end
  return <<-EOF
<html>
<body>
Hello from Flynn on port #{ ENV['PORT'] } from container #{ Socket.gethostname }
<br>
<br>
#{ @pg_status }
<br>
<br>
#{ @redis_status }
<br>
<br>
</body>
</html>
  EOF
end

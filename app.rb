require 'socket'
require 'sinatra'
require 'pg'
require 'redis'
require 'uri'

$stdout.sync = true

if ENV['DATABASE_URL']
  uri = URI.parse(ENV['DATABASE_URL'])
  $pg = PG::Connection.open host: uri.host,
                            user: uri.user,
                            password: uri.password,
                            port: uri.port || 5432,
                            dbname: uri.path[1..-1]

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
  @db_status = "Postgres not yet configured, you can add a database with `flynn resource add postgres`"
  if ENV['DATABASE_URL']
    $pg.exec("UPDATE counters SET counter = counter + 1 WHERE name = 'visitor_counter' RETURNING counter;") do |result|
      result.each do |row|
        @db_status = "Postgres visitor counter: %d" % row.values_at('counter')
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
#{ @db_status }
<br>
<br>
#{ @redis_status }
<br>
<br>
</body>
</html>
  EOF
end

require 'socket'
require 'sinatra'
require 'pg'
require 'redis'
require 'mysql'
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
    )
  EOF
  $pg.exec <<-EOF
    INSERT INTO counters (name, counter)
    SELECT 'visitor_counter', 0
    WHERE NOT EXISTS (SELECT name FROM counters WHERE name = 'visitor_counter')
  EOF
end

if ENV['MYSQL_HOST']
  $my = Mysql.new(ENV['MYSQL_HOST'], ENV['MYSQL_USER'], ENV['MYSQL_PWD'], ENV['MYSQL_DATABASE'], ENV['MYSQL_PORT'])

  $my.query <<-EOF
    CREATE TABLE IF NOT EXISTS counters (
      name VARCHAR(30) NOT NULL PRIMARY KEY,
      counter INT NOT NULL
    )
  EOF

  $my.query <<-EOF
    INSERT IGNORE INTO counters SET name = 'visitor_counter', counter = 0
  EOF
end

$redis = Redis.new if ENV['REDIS_URL']

get '/' do
  @pg_status = "Postgres not yet configured, you can add a postgres instance with `flynn resource add postgres`"
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

  @my_status = 'MySQL not yet configured, you can add a mysql instance with `flynn resource add mysql`'
  if ENV['MYSQL_HOST']
    $my.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ')
    $my.query("BEGIN")
    $my.query('UPDATE counters SET counter = @counter := counter + 1 WHERE name = "visitor_counter"')
    $my.query('SELECT @counter').each do |row|
      @my_status = "MySQL visitor counter: %s" % row.first
    end
    $my.query('COMMIT')
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
#{ @my_status }
<br>
<br>
</body>
</html>
  EOF
end

Redis.current = Redis::Namespace.new(
  [Rails.application.class.parent_name, Rails.env].join(':'),
  redis: Redis.new(
    host: 'yamapp-redis.gneihq.0001.apne1.cache.amazonaws.com',
    port: 6379
  )
)

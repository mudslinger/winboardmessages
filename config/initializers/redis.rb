Redis.current = Redis::Namespace.new(
  "yamaokaya:wbmessages",
  redis: Redis.new(
    host: 'yam-redis.gneihq.0001.apne1.cache.amazonaws.com',
    port: 6379
  )
)

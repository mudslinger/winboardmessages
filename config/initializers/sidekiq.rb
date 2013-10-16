conf = {
  url: 'redis://yamapp-redis.gneihq.0001.apne1.cache.amazonaws.com:6379',
  namespace: [Rails.application.class.parent_name, Rails.env,'sidekiq'].join(':')
}
Sidekiq.configure_server do |config|
  config.redis = conf
end
Sidekiq.configure_client do |config|
  config.redis = conf
end

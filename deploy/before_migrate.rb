Chef::Log.info("Running deploy/before_migrate.rb")
env = node[:deploy][:winboardmessages][:rails_env]
current_release = release_path

execute "sidekiq" do
  cwd current_release
  command "bundle exec sidekiq"
  environment "RAILS_ENV" => env
end
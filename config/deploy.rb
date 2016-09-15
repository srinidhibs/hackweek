require 'mina/bundler'
require 'mina/rails'
require 'mina/git'

# The hostname to SSH to
set :domain, 'blri2p01.blr.novell.com'
# SSH port number
set :port, '22'
# Username in the server to SSH to
set :user, 'srinidhi'
# Path to deploy into
set :deploy_to, '/srv/www/apps/i2p'
# Git repo to clone from
set :repository, 'https://github.com/srinidhibs/hackweek.git'
# Branch name to deploy
set :branch, 'i2p'

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, ['config/database.yml', 'config/application.yml', 'config/secrets.yml', 'log', 'tmp', 'public/gallery', 'en.pak', 'sphinx']

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/shared/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/log"]

  queue! %[mkdir -p "#{deploy_to}/shared/tmp"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/tmp"]

  queue! %[mkdir -p "#{deploy_to}/shared/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/config"]

  queue! %[mkdir -p "#{deploy_to}/shared/public/gallery"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/public/gallery"]

  queue! %[touch "#{deploy_to}/shared/config/database.yml"]
  queue  %[echo "-----> Be sure to edit 'shared/config/database.yml'."]

  queue! %[touch "#{deploy_to}/shared/config/application.yml"]
  queue  %[echo "-----> Be sure to edit 'shared/config/application.yml'."]

  queue! %[touch "#{deploy_to}/shared/config/secrets.yml"]
  queue  %[echo "-----> Be sure to edit 'shared/config/secrets.yml'."]

  queue! %[mkdir -p "#{deploy_to}/shared/sphinx/db"]
  queue! %[mkdir -p "#{deploy_to}/shared/sphinx/pids"]
  queue! %[mkdir -p "#{deploy_to}/shared/sphinx/binlog"]
  queue! %[mkdir -p "#{deploy_to}/shared/sphinx/config"]
  queue! %[touch "#{deploy_to}/shared/sphinx/config/production.sphinx.conf"]
  queue! %[wget 'http://sphinxsearch.com/files/dicts/en.pak' -O "#{deploy_to}/shared/en.pak"]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'
    invoke :notify_errbit

    to :launch do
      queue "/etc/init.d/apache2 restart"
      invoke :sphinx_restart
    end
  end
end

desc "Notifies the exception handler of the deploy."
task :notify_errbit do
  revision = `git rev-parse HEAD`.strip
  user = ENV['USER']
  queue "RAILS_ENV=#{rails_env} bundle exec rake hoptoad:deploy TO=#{rails_env} REVISION=#{revision} REPO=#{repository} USER=#{user}"
end

# TODO replace with appropriate Sphinx manipulations
desc "Restart Sphinx."
task :sphinx_restart do
  queue "cd #{deploy_to!}/#{current_path!} && RAILS_ENV=#{rails_env} bundle exec rake ts:regenerate"
end

desc "Reindex Sphinx data."
task :sphinx_reindex do
  queue "cd #{deploy_to!}/#{current_path!} && RAILS_ENV=#{rails_env} bundle exec rake ts:index"
end

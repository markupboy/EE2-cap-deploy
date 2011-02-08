################################################################################
# Capistrano recipe for deploying ExpressionEngine websites from GitHub        #
# By Dan Benjamin - http://example.com/                                        #
################################################################################


##### Settings #####

# the name of your website - should also be the name of the directory
set :application, "markupboy.com"

# the name of your system directory, which you may have customized
set :ee_system, "ee-system"

# the path to your new deployment directory on the server
# by default, the name of the application (e.g. "/var/www/sites/example.com")
set :deploy_to, "/home/mbadmin/web/markupboy.com"

# the path to the old (non-capistrano) ExpressionEngine installation
set :ee_previous_path, "/home/mbadmin/web/public"

# the git-clone url for your repository
set :repository, "git@github.com:markupboy/markupboy.com.git"

# the branch you want to clone (default is master)
set :branch, "master"

# the name of the deployment user-account on the server
set :user, "mbadmin"

# he shared host to pull your remote assets and database from
set :shared_host, "markupboy.com"





##### You shouldn't need to edit below unless you're customizing #####

# Additional SCM settings
set :scm, :git
set :ssh_options, { :forward_agent => true }
set :deploy_via, :remote_cache
set :copy_strategy, :checkout
set :keep_releases, 3
set :use_sudo, false
set :copy_compression, :bz2

# Roles
role :app, "#{application}"
role :web, "#{application}"
role :db,  "#{application}", :primary => true

# Deployment process
after "deploy:update", "deploy:cleanup" 
after "deploy", "deploy:set_permissions", "deploy:create_symlinks"

# Custom syncing tasks
namespace :sync do
  
  desc "Pull down production database for use locally"
  task :db_down, :roles => :app do
    # load the production settings within the database file
    remote_settings = YAML::load_file("config/database.yml")["production"]
    
    # we also need the local settings so that we can import the fresh database properly
    local_settings = YAML::load_file("config/database.yml")["development"]
    
    # dump the production database and store it in the current path's data directory
    run "mysqldump -u'#{remote_settings["username"]}' -p'#{remote_settings["password"]}' -h'#{remote_settings["host"]}' '#{remote_settings["database"]}' > #{current_path}/config/production-#{remote_settings["database"]}-dump.sql"
    
    # rsyncing the remote database dump with the local copy of the dump
    run_locally("rsync --times --rsh=ssh --compress --human-readable --progress #{user}@#{shared_host}:#{current_path}/config/production-#{remote_settings["database"]}-dump.sql config/production-#{remote_settings["database"]}-dump.sql")
    
    # make a backup of the local database, just in case
    run_locally("mampmysqldump -u#{local_settings["username"]} #{"-p#{local_settings["password"]}" if local_settings["password"]} #{local_settings["database"]} > config/development-backup-#{local_settings["database"]}-dump.sql")
    
    # now that we have the upated production dump file we should use the local settings to import this db.
    run_locally("mampmysql -u#{local_settings["username"]} #{"-p#{local_settings["password"]}" if local_settings["password"]} #{local_settings["database"]} < config/production-#{remote_settings["database"]}-dump.sql")
  end
  
  desc "Push local database to production"
  task :db_up, :roles => :app do
    # load the production settings within the database file
    remote_settings = YAML::load_file("config/database.yml")["production"]
    
    # we also need the local settings so that we can import the fresh database properly
    local_settings = YAML::load_file("config/database.yml")["development"]
    
    # dump the local database and store it in the current path's data directory
    run_locally("mampmysqldump -u#{local_settings["username"]} #{"-p#{local_settings["password"]}" if local_settings["password"]} #{local_settings["database"]} > config/development-#{remote_settings["database"]}-dump.sql")
    
    # rsyncing the remote database dump with the local copy of the dump
    run_locally("rsync --times --rsh=ssh --compress --human-readable --progress config/development-#{remote_settings["database"]}-dump.sql #{user}@#{shared_host}:#{current_path}/config/development-#{remote_settings["database"]}-dump.sql")
    
    # backup the remote database
    run "mysqldump -u'#{remote_settings["username"]}' -p'#{remote_settings["password"]}' -h'#{remote_settings["host"]}' '#{remote_settings["database"]}' > #{current_path}/config/production-backup-#{remote_settings["database"]}-dump.sql"
    
    # import the new database
    run "mysql -u'#{remote_settings["username"]}' -p'#{remote_settings["password"]}' -h'#{remote_settings["host"]}' '#{remote_settings["database"]}' < #{current_path}/config/development-#{remote_settings["database"]}-dump.sql"
    
  end
  
  task :content_down, :roles => :app do
    #############################
    #THIS NEEDS TO BE COMPLETED #
    #############################
  end
  
end

# Custom deployment tasks
namespace :deploy do

  desc "This is here to overide the original :restart"
  task :restart, :roles => :app do
    # do nothing but overide the default
  end

  task :finalize_update, :roles => :app do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
    # overide the rest of the default method
  end

  desc "Create additional EE directories and set permissions after initial setup"
  task :after_setup, :roles => :app do
    # create upload directories
    run "mkdir -p #{deploy_to}/#{shared_dir}/config"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets/images"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets/images/avatars/uploads"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets/images/captchas"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets/images/member_photos"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets/images/pm_attachments"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets/images/signature_attachments"
    run "mkdir -p #{deploy_to}/#{shared_dir}/assets/images/uploads"
    # set permissions
    run "chmod 777 #{deploy_to}/#{shared_dir}/assets/images/avatars/uploads"
    run "chmod 777 #{deploy_to}/#{shared_dir}/assets/images/captchas"
    run "chmod 777 #{deploy_to}/#{shared_dir}/assets/images/member_photos"
    run "chmod 777 #{deploy_to}/#{shared_dir}/assets/images/pm_attachments"
    run "chmod 777 #{deploy_to}/#{shared_dir}/assets/images/signature_attachments"
    run "chmod 777 #{deploy_to}/#{shared_dir}/assets/images/uploads"
  end

  desc "Copy user-uploaded content from existing installation to shared directory"
  task :copy_content, :roles => :app do
    # copy the content
    run "cp -r #{ee_previous_path}/images/avatars/uploads/* #{deploy_to}/#{shared_dir}/assets/images/avatars/uploads"
    run "cp -r #{ee_previous_path}/images/captchas/* #{deploy_to}/#{shared_dir}/assets/images/captchas"
    run "cp -r #{ee_previous_path}/images/member_photos/* #{deploy_to}/#{shared_dir}/assets/images/member_photos"
    run "cp -r #{ee_previous_path}/images/pm_attachments/* #{deploy_to}/#{shared_dir}/assets/images/pm_attachments"
    run "cp -r #{ee_previous_path}/images/signature_attachments/* #{deploy_to}/#{shared_dir}/assets/images/signature_attachments"
    run "cp -r #{ee_previous_path}/images/uploads/* #{deploy_to}/#{shared_dir}/assets/images/uploads"
    # reset permissions
    run "chmod -R 777 #{deploy_to}/#{shared_dir}/assets/images/avatars/uploads"
    run "chmod -R 777 #{deploy_to}/#{shared_dir}/assets/images/captchas"
    run "chmod -R 777 #{deploy_to}/#{shared_dir}/assets/images/member_photos"
    run "chmod -R 777 #{deploy_to}/#{shared_dir}/assets/images/pm_attachments"
    run "chmod -R 777 #{deploy_to}/#{shared_dir}/assets/images/signature_attachments"
    run "chmod -R 777 #{deploy_to}/#{shared_dir}/assets/images/uploads"
  end

  desc "Set the correct permissions for the config files and cache folder"
  task :set_permissions, :roles => :app do
    run "chmod 777 #{current_release}/#{ee_system}/expressionengine/cache/"
  end

  desc "Create symlinks to shared data such as config files and uploaded images"
  task :create_symlinks, :roles => :app do
    # the config file
    run "ln -s #{deploy_to}/#{shared_dir}/config/config.php #{current_release}/#{ee_system}/expressionengine/config/config.php" 
    run "ln -s #{deploy_to}/#{shared_dir}/config/database.php #{current_release}/#{ee_system}/expressionengine/config/database.php" 
    # standard image upload directories
    run "ln -s #{deploy_to}/#{shared_dir}/assets/images/avatars/uploads #{current_release}/images/avatars/uploads"
    run "ln -s #{deploy_to}/#{shared_dir}/assets/images/captchas #{current_release}/images/captchas"
    run "ln -s #{deploy_to}/#{shared_dir}/assets/images/member_photos #{current_release}/images/member_photos"
    run "ln -s #{deploy_to}/#{shared_dir}/assets/images/pm_attachments #{current_release}/images/pm_attachments"
    run "ln -s #{deploy_to}/#{shared_dir}/assets/images/signature_attachments #{current_release}/images/signature_attachments"
    run "ln -s #{deploy_to}/#{shared_dir}/assets/images/uploads #{current_release}/images/uploads"
  end

  desc "Clear the ExpressionEngine caches"
  task :clear_cache, :roles => :app do
    run "if [ -e #{current_release}/#{ee_system}/cache/db_cache ]; then rm -r #{current_release}/#{ee_system}/cache/db_cache/*; fi"
    run "if [ -e #{current_release}/#{ee_system}/cache/page_cache ]; then rm -r #{current_release}/#{ee_system}/cache/page_cache/*; fi"
    run "if [ -e #{current_release}/#{ee_system}/cache/magpie_cache ]; then rm -r #{current_release}/#{ee_system}/cache/magpie_cache/*; fi"
  end

end

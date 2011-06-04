################################################################################
# Capistrano recipe for deploying ExpressionEngine 2.x websites from GitHub    #
# By Blake Walters / @markupboy                                                #
# Based on original script by Dan Benjamin                                     #
################################################################################


##### Settings #####
set :local_db_settings, YAML::load_file("config/config.yml")["development"]

# Additional SCM settings
set :scm, :git
set :ssh_options, { :forward_agent => true }
set :deploy_via, :remote_cache
set :copy_strategy, :checkout
set :keep_releases, 3
set :use_sudo, false
set :copy_compression, :bz2

# Deployment process
after "deploy:update", "deploy:cleanup" 
after "deploy", "deploy:set_permissions", "deploy:create_symlinks"

on :load, "development"

# Custom syncing tasks
namespace :sync do
  
  desc "Pull down production database for use locally"
  task :db_down, :roles => :app do
    # dump the production database and store it in the current path's data directory
    run "mysqldump -u'#{remote_db_settings["username"]}' #{"-p#{remote_db_settings["password"]}" if remote_db_settings["password"]} -h'#{remote_db_settings["host"]}' '#{remote_db_settings["database"]}' > #{current_path}/config/production-#{remote_db_settings["database"]}-dump.sql"
    
    # rsyncing the remote database dump with the local copy of the dump
    run_locally("rsync --times --rsh=ssh --compress --human-readable --progress #{user}@#{shared_host}:#{current_path}/config/production-#{remote_db_settings["database"]}-dump.sql config/production-#{remote_db_settings["database"]}-dump.sql")
    
    # make a backup of the local database, just in case
    run_locally("mysqldump -u#{local_db_settings["username"]} #{"-p#{local_db_settings["password"]}" if local_db_settings["password"]} #{local_db_settings["database"]} > config/development-backup-#{local_db_settings["database"]}-dump.sql")
    
    # now that we have the upated production dump file we should use the local settings to import this db.
    run_locally("mysql -u#{local_db_settings["username"]} #{"-p#{local_db_settings["password"]}" if local_db_settings["password"]} #{local_db_settings["database"]} < config/production-#{remote_db_settings["database"]}-dump.sql")
  end
  
  desc "Push local database to production"
  task :db_up, :roles => :app do
    # dump the local database and store it in the current path's data directory
    run_locally("mysqldump -u#{local_db_settings["username"]} #{"-p#{local_db_settings["password"]}" if local_db_settings["password"]} #{local_db_settings["database"]} > config/development-#{remote_db_settings["database"]}-dump.sql")
        
    # rsyncing the remote database dump with the local copy of the dump
    run_locally("rsync --times --rsh=ssh --compress --human-readable --progress config/development-#{remote_db_settings["database"]}-dump.sql #{user}@#{shared_host}:#{current_path}/config/development-#{remote_db_settings["database"]}-dump.sql")
    
    # backup the remote database
    run "mysqldump -u'#{remote_db_settings["username"]}' #{"-p#{remote_db_settings["password"]}" if remote_db_settings["password"]} -h'#{remote_db_settings["host"]}' '#{remote_db_settings["database"]}' > #{current_path}/config/production-backup-#{remote_db_settings["database"]}-dump.sql"
    
    # import the new database
    run "mysql -u'#{remote_db_settings["username"]}' #{"-p#{remote_db_settings["password"]}" if remote_db_settings["password"]} -h'#{remote_db_settings["host"]}' '#{remote_db_settings["database"]}' < #{current_path}/config/development-#{remote_db_settings["database"]}-dump.sql"
    
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

namespace :recipe_debug do 
  
  task :default do
    #put cap recipe testing junk here
    puts local_db_settings.inspect
    puts remote_db_settings.inspect
  end
  
end

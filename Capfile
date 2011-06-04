#####################
#
# modified capfile to load stages from yaml
# code forked from https://github.com/leehambley/capistrano-yaml-multistage
#
#####################

require 'yaml'

load 'deploy' if respond_to?(:namespace)
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

@stages_from_yaml = YAML.load_file(File.join(Dir.pwd, 'config', 'config.yml'))

def load_config_for_stage(stage_name)
  config = @stages_from_yaml
  config[stage_name.to_s].each do |hash_key, hash_value|
    if hash_key =~ /application/
      role(:app, hash_value.to_s)
      role(:web, hash_value.to_s)
      role(:db, hash_value.to_s)
      set(:shared_host, hash_value.to_s)
    elsif hash_key =~ /_settings$/
      set(hash_key.to_sym, hash_value)
    else
      set(hash_key.to_sym, hash_value.to_s)
    end
  end
end

@stages_from_yaml.keys.each do |stage|
  code = <<-EOB
    desc "Set up and load config from YAML for the #{stage} stage."
    task :#{stage} do 
      # This method *actually* runs after the load statement below, 
      # but it is defined here, and called here, so that the variables 
      # exist before capistrano gets that far!
      load_config_for_stage('#{stage.to_s}')
    end 
  EOB
  puts code
  eval(code)
end

load 'config/deploy'
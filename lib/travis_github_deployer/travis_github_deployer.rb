#!/usr/bin/env ruby -w

require 'yaml'
require 'pathname'
require 'fileutils'

class TravisGithubDeployer
  
  def initialize
    @git = GitCommandLine.new
  end
  
  ## Configuration values
  
  def destination_repository
    @destination_repository
  end
  
  def destination_repository_dir
    @destination_repository_dir ||= "travis_github_deployer_repository"
  end
  
  def git
    @git
  end
  
  def verbose
    @verbose ||= false
  end
  
  def verbose=(value)
    git.verbose = value
    @verbose = value
  end
  
  def files_to_deploy
    @files_to_deploy ||= {}
  end
    
  def files_to_purge
    @files_to_purge ||= []
  end
    
  ## Deployment 
    
  def deploy
    if (environment_variable_value('TRAVIS_PULL_REQUEST') != "false")
      puts "In pull request and won't be deploying"
      return
    end
    
    if (ENV['GIT_NAME'].nil?)
      puts "In fork and won't be deploying"
      return
    end
    
    load_configuration
    clone_destination_repository
    copy_files_in_destination_repository
    change_current_directory_to_cloned_repository
    prepare_credentials_based_on_environment_variables
    purge_files_from_history if not files_to_purge.empty?
    commit_and_push_files
  end

  ## Preparing for deployment

  def load_configuration
    configuration = YAML.load_file(".travis_github_deployer.yml")
    @destination_repository = configuration["destination_repository"]
    prepare_files_to_deploy(configuration["files_to_deploy"])
  end
  
  def get_destination_and_add_file_to_purge source, target_or_hash
      if target_or_hash.instance_of?(Hash)
        files_to_purge << source if target_or_hash["purge"]   
        destination_file = target_or_hash["destination"]
      else
        destination_file = target_or_hash
      end
  end
  
  def prepare_files_to_deploy files_hash
    files_hash.each { |source, values|
      
      source_files = Dir.glob(source)      
      if source_files.empty?
        raise StandardError.new("File: '#{source}' found in the configuration didn't exist. Deploy failed.") 
      end
      
      destination_file = get_destination_and_add_file_to_purge(source, values)  
      source_files.each { |source_file|
        files_to_deploy[source_file] = destination_file
      }
    }
  end
  
  def command_line_arguments(arguments)
    if (arguments[0] == "-v")
      self.verbose = true
    end
  end

  def clone_destination_repository
    git.clone(destination_repository, destination_repository_dir)
  end
  
  def change_current_directory_to_cloned_repository
    Dir.chdir(destination_repository_dir)
  end

  def prepare_credentials_based_on_environment_variables
    set_username_based_on_environment_variable
    set_email_based_on_environment_variable
    set_repository_token_based_on_enviroment_variable
  end
  
  def set_repository_token_based_on_enviroment_variable
    git_token = environment_variable_value("GIT_TOKEN")
    git.config_credential_helper_store_file(".git/travis_deploy_credentials")
    File.open(".git/travis_deploy_credentials", "w") { |credential_file|
      credential_file.write("https://#{git_token}:@github.com")
    }
  end
  
  def set_username_based_on_environment_variable
    git.config_username(environment_variable_value("GIT_NAME"))
  end
  
  def set_email_based_on_environment_variable
    git.config_email(environment_variable_value("GIT_EMAIL"))
  end
  
  def environment_variable_value (environment_variable_name)
    value = ENV[environment_variable_name]
    raise StandardError.new("The #{environment_variable_name} environment variable wasn't set.") if value.nil?
    value
  end
    
  def copy_files_in_destination_repository
    
    files_to_deploy.each { |source_location, destination_location|
      source = Pathname.new(source_location)
      destination = Pathname.new(destination_repository_dir)
      destination += destination_location
      FileUtils.cp_r(source, destination)
    }
    
  end
  
  def purge_files_from_history
     git.filter_branch(files_to_purge.join(" "))
  end
  
  def commit_and_push_files
    files_to_deploy.each { |source_location, destination_location|
      git.add(Pathname.new(destination_location))
    }
    git.commit("File deployed with Travis Github Deployer")
    if(files_to_purge.empty?) 
      git.push
    else
      git.force_push
    end
  end
end

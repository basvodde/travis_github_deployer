
require 'travis_github_deployer.rb'

describe "travis github deployer" do
  
  subject { TravisGithubDeployer.new}
    
  before(:each) do
    ENV::clear
    @git = double
    GitCommandLine.should_receive(:new).and_return(@git)
    subject
  end
  
  it "can deploy to an destination repository" do
    ENV['TRAVIS_PULL_REQUEST']="false"
    ENV['GIT_NAME']="Foo"
    subject.should_receive(:load_configuration)
    subject.should_receive(:clone_destination_repository)
    subject.should_receive(:change_current_directory_to_cloned_repository)
    subject.should_receive(:prepare_credentials_based_on_environment_variables)
    subject.should_receive(:copy_files_in_destination_repository)
    subject.should_receive(:commit_and_push_files)
    subject.deploy
  end
  
  it "will not deploy on a pull request" do
    ENV['TRAVIS_PULL_REQUEST']="10"
    subject.should_not_receive(:load_configuration)
    subject.should_receive(:puts).with("In pull request and won't be deploying")
    subject.deploy
  end
 
  it "will not deploy when run in a fork, e.g. when GIT_NAME isn't set" do
    ENV['TRAVIS_PULL_REQUEST']="false"
    subject.should_not_receive(:load_configuration)
    subject.should_receive(:puts).with("In fork and won't be deploying")
    subject.deploy
  end
  
  context "Prepare repository for being able to commit" do
    
    it "can clone the destination repository" do
      subject.should_receive(:destination_repository).and_return("https://github.com/cpputest/cpputest")
      subject.should_receive(:destination_repository_dir).and_return("destdir")
      @git.should_receive(:clone).with("https://github.com/cpputest/cpputest", "destdir")
      
      subject.clone_destination_repository
    end
    
    it "can change the directory to the cloned directory" do
      subject.should_receive(:destination_repository_dir).and_return("destinationdir")
      Dir.should_receive(:chdir).with("destinationdir")
      subject.change_current_directory_to_cloned_repository
    end
        
    it "Should be able to set the credentials for pushing stuff up" do
      subject.should_receive(:set_username_based_on_environment_variable)
      subject.should_receive(:set_email_based_on_environment_variable)
      subject.should_receive(:set_repository_token_based_on_enviroment_variable)
      subject.prepare_credentials_based_on_environment_variables
    end
    
    it "Should be able to set the username based on an environment variable" do
      ENV['GIT_NAME'] = "basvodde"
      @git.should_receive(:config_username).with("basvodde")
      subject.set_username_based_on_environment_variable    
    end
      
    it "Should be able to set the password based on an environment variable" do
      ENV['GIT_EMAIL'] = "basv@bestcompanythatexists.com"
      @git.should_receive(:config_email).with("basv@bestcompanythatexists.com")
      subject.set_email_based_on_environment_variable
    end
      
    it "Should be able to write the github token based on an environment variable" do
      credential_file = double
      ENV['GIT_TOKEN'] = "Token"
    
      @git.should_receive(:config_credential_helper_store_file).with(".git/travis_deploy_credentials")
      File.should_receive(:open).with(".git/travis_deploy_credentials", "w").and_yield(credential_file)
      credential_file.should_receive(:write).with("https://Token:@github.com")
    
      subject.set_repository_token_based_on_enviroment_variable
    end  
  end

  context "Prepare the changes that need to be made commit" do
    
    it "should be able to copy a file from the root of the source repository to the root of the destination reportistory" do
      subject.should_receive(:files_to_deploy).and_return( { "sourcefile" => ""})
      FileUtils.should_receive(:cp_r).with(Pathname.new("sourcefile"), Pathname.new("travis_github_deployer_repository"))
      subject.copy_files_in_destination_repository
    end
    
    it "Should be able to copy multiple files" do
      subject.should_receive(:files_to_deploy).and_return({ "dir/onefile" => "destonefile", "twofile" => "dir/desttwofile"})
      FileUtils.should_receive(:cp_r).with(Pathname.new("dir/onefile"), Pathname.new("travis_github_deployer_repository/destonefile"))
      FileUtils.should_receive(:cp_r).with(Pathname.new("twofile"), Pathname.new("travis_github_deployer_repository/dir/desttwofile"))
      subject.copy_files_in_destination_repository      
    end    
  end
  
  context "Actually committing the files" do
    
    it "can add, commit and push up the files" do
      subject.should_receive(:files_to_deploy).and_return({ "dir/onefile" => "destonefile", "twofile" => "dir/desttwofile"})
      @git.should_receive(:add).with(Pathname.new("destonefile"))
      @git.should_receive(:add).with(Pathname.new("dir/desttwofile"))
      @git.should_receive(:commit).with("File deployed with Travis Github Deployer")
      @git.should_receive(:push)
      subject.commit_and_push_files
    end
  end
  
  context "configuration" do
    it "can read configuration parameters out of the .travis_github_deployer.yml" do
      configuration = { 
        "destination_repository" => "https://github.com/cpputest/cpputest.github.io.git",
        "files_to_deploy" => [
             "source" => "source_dir/source_file",
             "target" => "destination_dir/destination_file",
             "purge" => "yes"
        ]
      }
    
      YAML.should_receive(:load_file).with(".travis_github_deployer.yml").and_return(configuration)
      subject.should_receive(:prepare_files_to_deploy).with([
         "source" => "source_dir/source_file",
         "target" => "destination_dir/destination_file",
         "purge" => "yes"
      ])
      subject.load_configuration
    
      subject.destination_repository.should== "https://github.com/cpputest/cpputest.github.io.git"
      
      subject.files_to_deploy["source_dir/source_file"].should==
      "destination_dir/destination_file"
    end
    
    it "can have files with wildcards in the configuration" do
      wild_card_files = { "source_dir/*" => "destination_dir" }
      Dir.should_receive(:glob).with("source_dir/*").and_return(["file1", "file2"])
      
      subject.prepare_files_to_deploy(wild_card_files)
      subject.files_to_deploy.should== { "file1" => "destination_dir", "file2" => "destination_dir" }
    end
    
    it "raises an error when one of the source files doesn't exists" do
      Dir.should_receive(:glob).with("not_exists").and_return([])
      expect { 
        subject.prepare_files_to_deploy( { "not_exists" => "" }) 
      }.to raise_error(StandardError, "File: 'not_exists' found in the configuration didn't exist. Deploy failed.")
    end
    
        
    it "isn't verbose by default" do
      subject.command_line_arguments([""])
      subject.verbose.should == false
    end
    
    it "can be made verbose using the -v" do
      @git.should_receive(:verbose=).with(true)

      subject.command_line_arguments(["-v"])

      subject.verbose.should== true      
    end
    
  end
end

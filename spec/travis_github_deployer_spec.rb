
require 'travis_github_deployer.rb'

describe "travis github deployer" do
  
  subject { TravisGithubDeployer.new}
    
  before(:each) do
    ENV::clear
    @git = double
    expect(GitCommandLine).to receive(:new).and_return(@git)
    subject
  end
  
  it "can deploy to an destination repository" do
    ENV['TRAVIS_PULL_REQUEST']="false"
    ENV['GIT_NAME']="Foo"
    expect(subject).to receive(:load_configuration)
    expect(subject).to receive(:clone_destination_repository)
    expect(subject).to receive(:change_current_directory_to_cloned_repository)
    expect(subject).to receive(:prepare_credentials_based_on_environment_variables)
    expect(subject).to receive(:copy_files_in_destination_repository)
    expect(subject).to receive(:commit_and_push_files)
    subject.deploy
  end
  
  it "will not deploy on a pull request" do
    ENV['TRAVIS_PULL_REQUEST']="10"
    expect(subject).not_to receive(:load_configuration)
    expect(subject).to receive(:puts).with("In pull request and won't be deploying")
    subject.deploy
  end
 
  it "will not deploy when run in a fork, e.g. when GIT_NAME isn't set" do
    ENV['TRAVIS_PULL_REQUEST']="false"
    expect(subject).not_to receive(:load_configuration)
    expect(subject).to receive(:puts).with("In fork and won't be deploying")
    subject.deploy
  end
  
  context "Prepare repository for being able to commit" do
    
    it "can clone the destination repository" do
      expect(subject).to receive(:destination_repository).and_return("https://github.com/cpputest/cpputest")
      expect(subject).to receive(:destination_repository_dir).and_return("destdir")
      expect(@git).to receive(:clone).with("https://github.com/cpputest/cpputest", "destdir")
      
      subject.clone_destination_repository
    end
    
    it "can change the directory to the cloned directory" do
      expect(subject).to receive(:destination_repository_dir).and_return("destinationdir")
      expect(Dir).to receive(:chdir).with("destinationdir")
      subject.change_current_directory_to_cloned_repository
    end
        
    it "Should be able to set the credentials for pushing stuff up" do
      expect(subject).to receive(:set_username_based_on_environment_variable)
      expect(subject).to receive(:set_email_based_on_environment_variable)
      expect(subject).to receive(:set_repository_token_based_on_enviroment_variable)
      subject.prepare_credentials_based_on_environment_variables
    end
    
    it "Should be able to set the username based on an environment variable" do
      ENV['GIT_NAME'] = "basvodde"
      expect(@git).to receive(:config_username).with("basvodde")
      subject.set_username_based_on_environment_variable    
    end
      
    it "Should be able to set the password based on an environment variable" do
      ENV['GIT_EMAIL'] = "basv@bestcompanythatexists.com"
      expect(@git).to receive(:config_email).with("basv@bestcompanythatexists.com")
      subject.set_email_based_on_environment_variable
    end
      
    it "Should be able to write the github token based on an environment variable" do
      credential_file = double
      ENV['GIT_TOKEN'] = "Token"
    
      expect(@git).to receive(:config_credential_helper_store_file).with(".git/travis_deploy_credentials")
      expect(File).to receive(:open).with(".git/travis_deploy_credentials", "w").and_yield(credential_file)
      expect(credential_file).to receive(:write).with("https://Token:@github.com")
    
      subject.set_repository_token_based_on_enviroment_variable
    end  
  end

  context "Prepare the changes that need to be made commit" do
    
    it "should be able to copy a file from the root of the source repository to the root of the destination repository" do
      expect(subject).to receive(:files_to_deploy).and_return( { "sourcefile" => ""})
      expect(FileUtils).to receive(:cp_r).with(Pathname.new("sourcefile"), Pathname.new("travis_github_deployer_repository"))
      subject.copy_files_in_destination_repository
    end
    
    it "Should be able to copy multiple files" do
      expect(subject).to receive(:files_to_deploy).and_return({ "dir/onefile" => "destonefile", "twofile" => "dir/desttwofile"})
      expect(FileUtils).to receive(:cp_r).with(Pathname.new("dir/onefile"), Pathname.new("travis_github_deployer_repository/destonefile"))
      expect(FileUtils).to receive(:cp_r).with(Pathname.new("twofile"), Pathname.new("travis_github_deployer_repository/dir/desttwofile"))
      subject.copy_files_in_destination_repository      
    end    
  end
  
  context "Actually committing the files" do
    
    it "can purge files from history and force-push" do
      files = ["dir/onefile", "twofile"]
      expect(subject).to receive(:files_to_purge).and_return(files, files)
      allow(@git).to receive_messages(add: nil, commit: nil)
      expect(@git).to receive(:filter_branch).with(files.join(" "))
      expect(@git).to receive(:force_push)
      subject.purge_files_from_history
      subject.commit_and_push_files
    end
  
    it "can add, commit and push up the files" do
      expect(subject).to receive(:files_to_deploy).and_return({ "dir/onefile" => "destonefile", "twofile" => "dir/desttwofile"})
      expect(@git).to receive(:add).with(Pathname.new("destonefile"))
      expect(@git).to receive(:add).with(Pathname.new("dir/desttwofile"))
      expect(@git).to receive(:commit).with("File deployed with Travis Github Deployer")
      expect(@git).to receive(:push)
      subject.commit_and_push_files
    end
  end
  
  context "configuration" do
    it "can read configuration parameters out of the .travis_github_deployer.yml" do
      files_to_deploy = { "source_dir/source_file" => "destination_dir/destination_file" }
      configuration = { 
        "destination_repository" => "https://github.com/cpputest/cpputest.github.io.git",
        "files_to_deploy" => files_to_deploy
      }
    
      expect(YAML).to receive(:load_file).with(".travis_github_deployer.yml").and_return(configuration)
      expect(subject).to receive(:prepare_files_to_deploy).with(files_to_deploy)
      subject.load_configuration
    
      expect(subject.destination_repository).to eq("https://github.com/cpputest/cpputest.github.io.git")
    
    end

    it "can parse destination with file to purge" do
      source = "src_file"
      target = {"destination"=>"dest", "purge"=>"yes"}
      expect(subject.get_destination_and_add_file_to_purge(source, target)).to eq("dest")
      expect(subject.files_to_purge).to eq(["src_file"])
    end
    
    it "can parse destination without file to purge" do
      source = "src_file"
      target = "dest"
      expect(subject.get_destination_and_add_file_to_purge(source, target)).to eq("dest")
      expect(subject.files_to_purge).to eq([])
    end
    
    it "can have sources to purge from history" do
      files_to_purge = { "myfile" => { "destination" => "destination_dir", "purge" => "yes" } }
      expect(Dir).to receive(:glob).with("myfile").and_return(["myfile"])
      
      subject.prepare_files_to_deploy(files_to_purge)
      expect(subject.files_to_deploy).to eq({ "myfile" => "destination_dir" })    
      expect(subject.files_to_purge).to eq([ "myfile" ])
    end
    
    it "can have files with wildcards in the configuration" do
      wild_card_files = { "source_dir/*" => "destination_dir" }
      expect(Dir).to receive(:glob).with("source_dir/*").and_return(["file1", "file2"])
      
      subject.prepare_files_to_deploy(wild_card_files)
      expect(subject.files_to_deploy).to eq({ "file1" => "destination_dir", "file2" => "destination_dir" })
    end
    
    it "raises an error when one of the source files doesn't exist" do
      expect(Dir).to receive(:glob).with("not_exists").and_return([])
      expect { 
        subject.prepare_files_to_deploy( { "not_exists" => "" }) 
      }.to raise_error(StandardError, "File: 'not_exists' found in the configuration didn't exist. Deploy failed.")
    end
    
        
    it "isn't verbose by default" do
      subject.command_line_arguments([""])
      expect(subject.verbose).to eq(false)
    end
    
    it "can be made verbose using the -v" do
      expect(@git).to receive(:verbose=).with(true)

      subject.command_line_arguments(["-v"])

      expect(subject.verbose).to eq(true)      
    end
    
  end
end

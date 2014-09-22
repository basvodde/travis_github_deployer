
require 'travis_github_deployer.rb'

describe "Travis Github Deployer" do
  
  subject { TravisGithubDeployer.new}
    
  before(:each) do
    ENV::clear
    @git = double
    expect(GitCommandLine).to receive(:new).and_return(@git)
    subject
  end
  
  context "can deploy to a destination repository" do
  
     before(:each) do
      ENV['TRAVIS_PULL_REQUEST']="false"
      ENV['GIT_NAME']="Foo"
      expect(subject).to receive(:load_configuration)
      expect(subject).to receive(:clone_destination_repository)
      expect(subject).to receive(:prepare_credentials_based_on_environment_variables)
      expect(subject).to receive(:copy_files_in_destination_repository)
      expect(subject).to receive(:change_current_directory_to_cloned_repository)
      expect(subject).to receive(:commit_and_push_files)
    end
    
    it "without files to purge" do
      subject.deploy
    end
    
    it "with files to purge" do
      expect(subject).to receive(:purge_files_from_last_commit)
      subject.files_to_purge << "foo"
      subject.deploy
    end
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
  
  context "preparing repository for being able to commit" do
    
    it "can clone the destination repository" do
      expect(subject).to receive(:destination_repository).and_return("https://github.com/cpputest/cpputest")
      expect(subject).to receive(:destination_repository_dir).and_return("destdir")
      expect(@git).to receive(:clone).with("https://github.com/cpputest/cpputest", "destdir")
      
      subject.clone_destination_repository
    end
    
    it "can store the original directory" do
      expect(subject.pwd).to eq(Dir.pwd)
    end
        
    it "can change the directory to the cloned directory" do
      expect(subject).to receive(:destination_repository_dir).and_return("destinationdir")
      expect(Dir).to receive(:chdir).with("destinationdir")
      subject.change_current_directory_to_cloned_repository
    end
        
    it "can change back to original directory" do
      expect(subject).to receive(:pwd).and_return("currentdir")
      expect(Dir).to receive(:chdir).with("currentdir")
      subject.change_current_directory_back_to_original
    end
        
    it "should be able to set the credentials for pushing stuff up" do
      expect(subject).to receive(:set_username_based_on_environment_variable)
      expect(subject).to receive(:set_email_based_on_environment_variable)
      expect(subject).to receive(:set_repository_token_based_on_enviroment_variable)
      subject.prepare_credentials_based_on_environment_variables
    end
    
    it "should be able to set the username based on an environment variable" do
      ENV['GIT_NAME'] = "basvodde"
      expect(@git).to receive(:config_username).with("basvodde")
      subject.set_username_based_on_environment_variable    
    end
      
    it "should be able to set the password based on an environment variable" do
      ENV['GIT_EMAIL'] = "basv@bestcompanythatexists.com"
      expect(@git).to receive(:config_email).with("basv@bestcompanythatexists.com")
      subject.set_email_based_on_environment_variable
    end
      
    it "should be able to write the github token based on an environment variable" do
      credential_file = double
      ENV['GIT_TOKEN'] = "Token"
    
      expect(@git).to receive(:config_credential_helper_store_file).with(".git/travis_deploy_credentials")
      expect(File).to receive(:open).with(".git/travis_deploy_credentials", "w").and_yield(credential_file)
      expect(credential_file).to receive(:write).with("https://Token:@github.com")
    
      subject.set_repository_token_based_on_enviroment_variable
    end  
  end

  context "preparing the changes that need to be made commit" do
    
    it "should be able to copy a file from the root of the source repository to the root of the destination repository" do
      expect(subject).to receive(:files_to_deploy).and_return( { "sourcefile" => ""})
      expect(FileUtils).to receive(:cp_r).with(Pathname.new("sourcefile"), Pathname.new("travis_github_deployer_repository"))
      subject.copy_files_in_destination_repository
    end
    
    it "should be able to copy multiple files" do
      expect(subject).to receive(:files_to_deploy).and_return({ "dir/onefile" => "destonefile", "twofile" => "dir/desttwofile"})
      expect(FileUtils).to receive(:cp_r).with(Pathname.new("dir/onefile"), Pathname.new("travis_github_deployer_repository/destonefile"))
      expect(FileUtils).to receive(:cp_r).with(Pathname.new("twofile"), Pathname.new("travis_github_deployer_repository/dir/desttwofile"))
      subject.copy_files_in_destination_repository      
    end    
  end
  
  context "actually committing the files" do
    
    it "can purge files from latest commit and force-push" do
      files = ["dir/onefile", "twofile"]
      allow(Dir).to receive(:chdir)
      allow(@git).to receive_messages(add: nil, commit: nil)
      expect(subject).to receive(:files_to_purge).and_return(files).twice
      expect(@git).to receive(:reset).with(files.join(" "))
      expect(@git).to receive(:amend_commit)
      expect(@git).to receive(:force_push)
      subject.purge_files_from_last_commit
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

    it "can parse destination as hash" do
      target = {"destination"=>"dest/dest_file", "purge"=>true}
      allow(File).to receive(:exists?).and_return(true)
      expect(subject.get_destination_and_add_file_to_purge("src_file", target)).to eq("dest/dest_file")
      expect(subject.files_to_purge).to eq(["dest/dest_file"])
    end
    
    it "can parse destination as string" do
      expect(subject.get_destination_and_add_file_to_purge("src_file", "dest")).to eq("dest")
      expect(subject.files_to_purge).to eq([])
    end
    
    it "can determine file to purge when target is a directory" do
      expect(File).to receive(:directory?).with("destination_dir").and_return(true)
      allow(File).to receive(:exists?).and_return(true)
      expect(subject.add_file_to_purge("myfile", "destination_dir")).to eq(["destination_dir/myfile"])
    end
    
    it "can determine file to purge when target is a file" do
      expect(File).to receive(:directory?).with("yourdir/myfile").and_return(false)
      allow(File).to receive(:exists?).and_return(true)
      expect(subject.add_file_to_purge("myfile", "yourdir/myfile")).to eq(["yourdir/myfile"]) 
    end
    
    it "raises an error when file to purge doesn't exist" do
      expect(File).to receive(:exists?).with("not_exists").and_return(false)
      expect { 
        subject.add_file_to_purge("not_exists", "not_exists") 
      }.to raise_error(StandardError, "File: 'not_exists' found in the configuration didn't exist. Purge failed.")
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
    
   it "parses the real yaml file correctly" do
      allow(File).to receive(:directory?).and_return(true).twice
      allow(File).to receive(:exists?).and_return(true).twice
      allow(subject).to receive (:prepare_files_to_deploy) do |files_hash|
        files_hash.each { |source, values|
          subject.get_destination_and_add_file_to_purge(source, values)  
        }
      end
          
      subject.load_configuration
      expect(subject.files_to_purge).to eq(
        ["releases/cpputest-3.7dev.tar.gz", "releases/cpputest-3.7dev.zip"]
      )
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

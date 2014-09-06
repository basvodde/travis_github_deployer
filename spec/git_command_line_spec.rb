
require 'travis_github_deployer.rb'

describe "simple ruby interface around git command line" do
  
  subject { GitCommandLine.new}
  
  it "can do a git clone" do
    expect(subject).to receive(:git).with("clone repository destination")
    subject.clone("repository", "destination")
  end
  
  it "can add files" do
    expect(subject).to receive(:git).with("add filename")
    subject.add("filename")
  end
  
  it "can commit" do
    expect(subject).to receive(:git).with('commit -m "message"')
    subject.commit("message")
  end
  
  it "can push" do
    expect(subject).to receive(:git).with("push")
    subject.push
  end
  
  it "can do a config" do
    expect(subject).to receive(:git).with("config key 'value'")
    subject.config("key", "value")
  end
  
  it "can configure the username" do
    expect(subject).to receive(:config).with("user.name", "basvodde")
    subject.config_username("basvodde")
  end
  
  it "can configure the email" do
    expect(subject).to receive(:config).with("user.email", "basv@sokewl.com")
    subject.config_email("basv@sokewl.com")
  end
  
  it "can configure the credential helper" do
    expect(subject).to receive(:config).with("credential.helper", "store --file=filename")
    subject.config_credential_helper_store_file("filename")
  end
  
  it "can do verbose output" do
    subject.verbose=true
    expect(subject).to receive(:puts).with("command: git something")
    expect(subject).to receive(:do_system).with("git something 2>&1").and_return("output")
    expect(subject).to receive(:previous_command_success).and_return(true)
    expect(subject).to receive(:puts).with("output: output")
    subject.git("something")    
  end
  
  it "Should be able to do a successful command" do
    expect(subject).not_to receive(:puts)
    expect(subject.git('version')).to start_with("git version")
  end
  
  it "Should be able to raise an StandardError on failed commands" do
    expect {
      subject.git('error')
    }.to raise_error(StandardError, "Git command: 'error' failed. Message: : git: 'error' is not a git command. See 'git --help'.\n\nDid you mean this?\n	rerere\n")
  end
end

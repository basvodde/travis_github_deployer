

class GitCommandLine
  
  def clone(repository, destination)
    git("clone " + repository + " " + destination)
  end
  
  def config(key, value)
    git("config #{key} '#{value}'")
  end
  
  def add(filename)
    git("add #{filename}")
  end
  
  def commit(message)
    git("commit -m \"#{message}\"")
  end
  
  def filter_branch(patterns)
    git("filter-branch --force --index-filter " +
        "'git rm --cached --ignore-unmatch #{patterns}' " +
        "--prune-empty --tag-name-filter cat -- --all"
    )
  end
  
  def force_push
    git("push -f")
  end
  
  def push
    git("push")
  end
  
  def config_username(username)
    config("user.name", username)
  end
  
  def config_email(email)
    config("user.email", email)
  end
  
  def config_credential_helper_store_file(filename)
    config("credential.helper", "store --file=#{filename}")
  end
  
  def verbose=(value)
    @verbose = true
  end
  
  def verbose
    @verbose
  end
  
  def git(command)
    git_command = "git #{command}"
    puts("command: #{git_command}") if verbose
    output = do_system("#{git_command} 2>&1")
    puts("output: #{output}") if verbose
    raise StandardError, "Git command: '#{command}' failed. Message: : " + output unless previous_command_success
    output
  end
  
  def do_system(command)
    `#{command}`
  end
  
  def previous_command_success
    $?.success?
  end
  
end
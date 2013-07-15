Travis to Github Deployer
======================

The Travis to Github Deployer script helps when you want to deploy files from a Travis CI build into a github repository. This is especially useful when you use Github Pages, so that you can push certain build artifacts to the github pages such as coverage, test results or generated documentation

# How does it work

The Travis Github Deployer clones a repository and copies files from the build into that repository. It then pushes these files into the github repository.

## Setting up the Github permissions

In order for Travis CI to be 'allowed' to push up the changes into a Github repository, you'll need to configure travis CI. The Travis Github Deployer will use the following .travis.yml environment variables:

* GIT_NAME
* GIT_EMAIL
* GIT_TOKEN

You can set up these environment variables in a secure way using the travis gem, in the following way:

{% highlight bash %}
$ gem install travis
$ cd <name of your repository>
$ curl -u <your username> -d '{"scopes":["public_repo"],"note":"Travis CI deployer"}' https://api.github.com/authorizations
$ travis encrypt 'GIT_NAME="<your name>" GIT_EMAIL=<your email> GH_TOKEN=<your token>' --add
{% endhighlight %}

### How does this work?

The following command:

{% highlight bash %}
$ curl -u <your username> -d '{"scopes":["public_repo"],"note":"Travis CI deployer"}' https://api.github.com/authorizations
{% endhighlight %}

This will get an authentication token. With it, Travis CI can commit under your name. So be careful with it. Then with the following command:

{% highlight bash %}
$ travis encrypt 'GIT_NAME="<your name>" GIT_EMAIL=<your email> GH_TOKEN=<your token>' --add
{% endhighlight %}

This will take the taken and add it to a 'secure' section in your travis.yml. The Travis Github Deployer will grab it from that section and use it to push up the changes to your repository

## Setting up the Travis Github Deployer

The Travis Github Deployer uses one config file: ".travis_github_deployer"

A typical file looks like this:

{% highlight yaml %}

destination_repository: https://github.com/basvodde/travis_github_deployer.git

files_to_deploy:
  source_dir/source_file: destination_dir/destination_file
  another_file: another_dir/new_name

{% endhighlight %}

This yaml file configures the repository to push to to be travis_github_deployer.git and it will copy 2 files from the build into the repository: source_dir/source_file and another_file. It will copy them to destination: destination_dir/destination_file and another_dir/new_name.

## Running Travis Github Deployer







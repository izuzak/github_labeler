# GitHub Labeler

GitHub Labeler helps you with bulk label operations on groups of GitHub repositories, such as adding a label to a set of repositories, or duplicating labels form one repository to another.

Built using [Octokit](https://github.com/octokit/octokit.rb), [commander](https://github.com/commander-rb/commander) and the [GitHub API](https://developer.github.com/v3/).

# Install

```
gem install github_labeler
```

# Usage

Run this to see the list of available commands and options, and also examples:

```
github_labeler help
```

Commands are executed like this:

```
github_labeler <command> [options]
```

Available commands:

* `add` - Add one or more label to one or more repositories
* `delete` - Delete one or more label from one or more repositories
* `recolor` - Recolor one or more labels in one or more repositories
* `rename` - Rename one or more labels in one or more repositories  
* `duplicate` - Duplicate labels from one repository to another
* `export` - Export a list of labels from a repository or list of repositories
* `execute` - Execute changes previously created by the program

To see the list of options and usage examples for a specific command, run this:

```
github_labeler help <command>
```

There are several global options:

* `--token` - Tells `github_labeler` which token to use for making [authenticated](https://developer.github.com/v3/#authentication) GitHub API calls. If `--token` is not used, `github_labeler` will look for it in the `GITHUB_OAUTH_TOKEN` environment variable. You can create a token [here](https://github.com/settings/tokens). The token needs to have `public_repo` [scope](https://developer.github.com/v3/oauth/#scopes) if the repositories you're working with are public, or `repo` scope if the repositories you're working with are private.

* `--verbose` - Tells `github_labeler` to output detailed debugging information to `STDERR`.

* `--execute` - Tells `github_labeler` to execute the required changes immediately, without asking for confirmation. Without this option, you will be asked if you want to execute the changes. In addition, `github_labeler` will output the changes to STDOUT so you can redirect the output to a file and then use the `execute` command later to execute those changes.

# Use cases and examples

Here are a few common use-cases and examples of running commands. Note: I've defined my GitHub token in the `GITHUB_OAUTH_TOKEN` so I don't need to specify it with every command.

#### Duplicate labels from one repository to another

Copy labels from repository `izuzak/labels1` to repository `izuzak/labels2`:

```
github_labeler duplicate --source=izuzak/labels1 --destination=izuzak/labels2 --verbose
```

#### Add a label to a repository or list of repositories

Add label `api` with color `c7def8` to a single repository:

```
github_labeler add -r izuzak/labels1 -l api#c7def8
```

Add the same label to a list of repositories:

```
github_labeler add -r repos.json -l api#c7def8
```

Where `repos.json` is a JSON file with the following format:

```json
[
  {
    "full_name": "izuzak/labels1"
  },
  {
    "full_name": "izuzak/labels2"
  }
]
```

A simpler format can be used as well:

```json
[ "izuzak/labels1", "izuzak/labels2" ]
```

You can get such a list from [GitHub API](https://developer.github.com/v3/) endpoints which return a list of repositories, for example [this](https://developer.github.com/v3/repos/#list-organization-repositories): https://api.github.com/orgs/github/repos. The response will include a bunch of other fields, but those are ignored and only `full_name` is used by `github_labeler`.

#### Add a list of labels to a repository

Export the list of labels from one repository or construct the file manually:

```
github_labeler export -r izuzak/labels1 > labels.json
```

Make changes to the list of labels in `labels.json`, and then add them to a repository:

```
github_labeler add -l labels.json -r izuzak/labels2
```

#### Update labels

Rename a label `design` to `ui` in a single repository:

```
github_labeler rename -r izuzak/labels1 -l design/ui
```

Change the color of label `ui` to `c7def8` in a single repository:

```
github_labeler recolor -r izuzak/labels1 -l ui#c7def8
```

# Roadmap

* If the remaining API rate limit is not enough to execute changes, allow the user to decide if at least some changes should be executed.

* Catch exceptions from API responses, e.g. 401s or 404s, and recover gracefully.

* Handle common errors, e.g. when the input JSON format is incorrect.

* Tests. :(

# Similar projects

* https://github.com/julien-vidal/github-label-manager
* https://github.com/destan/github-label-manager

# License

[MIT](LICENSE.txt)

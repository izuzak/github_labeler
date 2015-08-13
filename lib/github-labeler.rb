require "json"
require "logger"
require "Octokit"

Octokit.auto_paginate = true

class GitHubLabeler
  attr_accessor :client,          # Octokit client for acesing the API
                :repo_labels      # Labels cache for repositories
                :logger           # Logger for writing debugging info

  def initialize(token, verbose=false, labels=nil)
    @logger = Logger.new(STDERR)
    @logger.sev_threshold = verbose ? Logger::DEBUG : Logger::WARN

    @logger.debug "Creating new GitHubLabeler instance."

    @logger.debug "Creating a new Octokit client with token #{token[0..5]}"

    begin
      @client = Octokit::Client.new(:access_token => token)
      @client.rate_limit
    rescue Octokit::Unauthorized => exception
      @logger.error "Token #{token[0..5]} is not valid"
      raise ArgumentError.new("Token #{token[0..5]} is not valid")
    end

    @logger.debug "Token #{token[0..5]} is valid"

    @repo_labels = !labels.nil? ? labels : {}
  end

  #
  # Checks if the remaining rate limit allows us to make the specified number of
  # changes
  #
  def is_remaining_rate_limit_sufficient?(expected_number_of_calls)
    remaining_limit = @client.rate_limit.remaining

    @logger.debug "There are #{expected_number_of_calls} API calls to be made, and the remaining API rate limit quota is #{remaining_limit}."

    return expected_number_of_calls <= @client.rate_limit.remaining
  end

  #
  # Executes a list of label changes. Each change has the following format:
  #
  # {
  #   :type => "update/create/delete",
  #   :repo => "testrename/testing",
  #   :label => {:color => "fc2929", :name => "design", :new_name => "ui"}
  # }
  #
  def execute_changes(changes, options = {})
    @logger.debug "Executing changes"

    if !is_remaining_rate_limit_sufficient?(changes.size)
      @logger.error "Remaining rate limit is not enough to make all changes. Wait for the limit to refresh and try again."
      return []
    end

    changes = validate_changes(changes, options)

    changes.each do |change|
      @logger.debug "Executing change: #{change_string(change)}"

      if change[:type] == "add"
        success = @client.add_label(change[:repo], change[:label][:name], change[:label][:color])

        if !@repo_labels[change[:repo]].nil?
          @repo_labels[change[:repo]][success[:name].downcase] = {:name => success[:name], :color => success[:color]}
        end

        @logger.debug "Change succeded"
        next
      end

      if change[:type] == "update"
        new_label = {:name => change[:label][:new_name] || change[:label][:name]}
        if !change[:label][:color].nil?
          new_label[:color] = change[:label][:color]
        end

        success = @client.update_label(change[:repo], change[:label][:name], new_label)

        if !@repo_labels[change[:repo]].nil?
          @repo_labels[change[:repo]][success[:name].downcase] = {:name => success[:name], :color => success[:color]}
        end

        @logger.debug "Change succeded"
        next
      end

      if change[:type] == "delete"
        success = @client.delete_label!(change[:repo], change[:label][:name])

        if !@repo_labels[change[:repo]].nil?
          @repo_labels[change[:repo]][change[:label][:name].downcase] = nil
        end

        @logger.debug "Change succeded"
        next
      end
    end

    @logger.debug "Done executing changes"

    return changes
  end

  #
  # Updates repo labels cache for a specific label
  #
  def update_repos_labels_cache(repo, label)
    @repo_labels[change[:repo]][change[:label][:name].downcase] = success
  end

  #
  # Validates changes by merging multiple updates into one, removing
  # duplicates, detecting conflicts, etc.
  #
  def validate_changes(changes, options = {})
    return changes.sort_by { |hsh| [hsh["repo"], hsh["type"]] }
  end

  #
  # Create changes for adding a list of labels to a list of repos
  #
  def add_labels_to_repos(repos, labels, options = {})
    @logger.debug "Adding labels to repositories"
    return process_labels_for_repos(repos, labels, method(:add_label_to_repo), options)
  end

  #
  # Create changes for deleting a list of labels from a list of repos
  #
  def delete_labels_from_repos(repos, labels, options = {})
    @logger.debug "Deleting labels from repositories"
    return process_labels_for_repos(repos, labels, method(:delete_label_from_repo), options)
  end

  #
  # Create changes for renaming a list of labels in a list of repos
  #
  def rename_labels_in_repos(repos, labels, options = {})
    @logger.debug "Renaming labels in repositories"
    return process_labels_for_repos(repos, labels, method(:rename_label_in_repo), options)
  end

  #
  # Create changes for recoloring a list of labels in a list of repos
  #
  def recolor_labels_in_repos(repos, labels, options = {})
    @logger.debug "Recoloring labels in repositories"
    return process_labels_for_repos(repos, labels, method(:recolor_label_in_repo), options)
  end

  #
  # Generic creation of changes for list of labels and list of repos
  #
  def process_labels_for_repos(repos, labels, change_creator, options = {})
    if !is_remaining_rate_limit_sufficient?(repos.size)
      @logger.error "Rate limit is not enough to process all labels in repositories"
      return nil
    end

    changes = []

    for repo in repos
      repo_name = repo if repo.instance_of?(String)
      repo_name = repo[:full_name] if repo.instance_of?(Hash)

      @logger.debug "Processing labels for repository #{repo_name}"

      refresh_repo_labels(repo_name, options)

      for label in labels
        @logger.debug "Processing label #{label[:name]}"
        change = change_creator.call(repo_name, label, options)
        changes << change if !change.nil?
      end
    end

    return changes
  end

  #
  # Fetches the list of labels in a repository and stores them
  # in the labels cache
  #
  def refresh_repo_labels(repo, options = {})
    @logger.debug "Fetching label information for #{repo}"

    @repo_labels[repo] = {}
    @client.labels(repo).each do |label|
      @repo_labels[repo][label[:name].downcase] = label
    end
  end

  #
  # Create a single change for adding a label to a repo
  #
  def add_label_to_repo(repo, label, options = {})
    existing_label = @repo_labels[repo][label[:name].downcase]

    if existing_label
      if existing_label[:color] != label[:color] or existing_label[:name] != label[:name]
        @logger.warn "Label #{label[:name]} already exist, creating an update"
        return { :type => "update", :repo => repo, :label => label }
      end
    else
      return { :type => "add", :repo => repo, :label => label }
    end

    @logger.warn "Label #{label[:name]} already exist and is the same. No change created"
    return nil
  end

  #
  # Create a single change for deleting a label from a repo
  #
  def delete_label_from_repo(repo, label, options = {})
    existing_label = @repo_labels[repo][label[:name].downcase]

    if existing_label
      return { :type => "delete", :repo => repo, :label => label }
    end

    @logger.warn "Label #{label[:name]} doesn't exist. No change created"
    return nil
  end

  #
  # Create a single change for renaming a label in a repo
  #
  def rename_label_in_repo(repo, label, options = {})
    existing_label = @repo_labels[repo][label[:name].downcase]

    if existing_label
      if label[:new_name] and label[:new_name] != label[:name]
        return { :type => "update", :repo => repo, :label => label }
      end
    else
      @logger.warn "Label #{label[:name]} doesn't exist. Creating a create change"
      newLabel = {:name => label[:new_name], :color => label[:color]}
      return { :type => "add", :repo => repo, :label => newLabel }
    end

    @logger.warn "Label #{label[:name]} exist and is the same. No change created"
    return nil
  end

  #
  # Create a single change for recoloring a label in a repo
  #
  def recolor_label_in_repo(repo, label, options = {})
    existing_label = @repo_labels[repo][label[:name].downcase]

    if existing_label
      if existing_label[:color] != label[:color]
        return { :type => "update", :repo => repo, :label => label }
      end
    else
      @logger.warn "Label #{label[:name]} doesn't exist. Creating a create change"
      return { :type => "add", :repo => repo, :label => label }
    end

    @logger.warn "Label #{label[:name]} exist and is the same. No change created"
    return nil
  end

  #
  # Creates changes for duplicating labels from one repo to other repos
  #
  def duplicate_labels_from_repo(repo_source, repos_end, options = {})
    @logger.debug "Duplicating labels from repo #{repo_source}"
    source_repo_labels = export_labels_from_repo(repo_source, options)
    return add_labels_to_repos(repos_end, source_repo_labels, options)
  end

  #
  # Fetches a list of labels for a repository
  #
  def export_labels_from_repo(repo, options = {})
    @logger.debug "Exporting labels from repo #{repo}"

    @client.labels(repo).map do |label|
      { :name => label[:name], :color => label[:color] }
    end
  end

  #
  # Get a human readable string representation of a change
  #
  def change_string(change, options = {})
    return "#{change[:repo]} - #{change[:type]} - #{change[:label][:name]} - color: #{change[:label][:color]} - new_name: #{change[:label][:new_name]}"
  end
end

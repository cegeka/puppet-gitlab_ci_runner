require 'net/http'
require 'uri'
require 'json'

Puppet::Functions.create_function(:'gitlab_ci_runner::register_runner') do
  def register_runner(*args)
    gitlab_api_token = args[0]
    groupid = args[1]
    additional_tags = args[2]
    gitlab_api_url = args[3]
    runner_name = args[4]

    unless Dir.exists?("/etc/gitlab-runners-tokens")
      Dir.mkdir("/etc/gitlab-runners-tokens")
    end

    if ! File.exist?("/etc/gitlab-runners-tokens/#{runner_name}_token")
      file = File.new("/etc/gitlab-runners-tokens/#{runner_name}_token", "w")
      file.close
    end

    if File.zero?("/etc/gitlab-runners-tokens/#{runner_name}_token")

      # additional_tags comes in as an array so we need to exclude the []
      processed_additional_tags = additional_tags.join(',')

      # Merge all Gitlab Runner tags in one variable
      tags_list = "computing-managed,#{runner_name}"
      tags_list += ",#{processed_additional_tags}" unless processed_additional_tags.nil? || processed_additional_tags.empty?

      # GitLab API call to register a runner
      gitlab_uri = URI.parse("#{gitlab_api_url}/user/runners")
      gitlab_response = Net::HTTP.post_form(
      gitlab_uri,
      'runner_type' => 'group_type',
      'group_id'    => groupid,
      'description' => runner_name,
      'tag_list' => tags_list,
      'private_token' => gitlab_api_token
      )

      unless gitlab_response.kind_of?(Net::HTTPSuccess)
          raise Puppet::Error, "Failed to register runner. HTTP Code: #{gitlab_response.code}"
      end

      gitlab_response_data = JSON.parse(gitlab_response.body)
      gitlab_runner_registration_token = gitlab_response_data['token']
      
      File.open("/etc/gitlab-runners-tokens/#{runner_name}_token", "a") do |file|
        file.puts gitlab_runner_registration_token
        file.close
      end

      return gitlab_runner_registration_token

    else
      file = File.open("/etc/gitlab-runners-tokens/#{runner_name}_token")
      token = file.read.chomp
      file.close
      return token
    end
  end
end
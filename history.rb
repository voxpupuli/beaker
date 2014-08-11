# Generates a HISTORY.md file for your repo based on tags and commits, defaults to history for 
#     master branch but can generate history for specified branch
#
# Requires: gem install gitlab-grit
# Usage: ruby history.rb /your/repo/directory
#
# Based on https://coderwall.com/p/99mjcg

require 'grit'

if ARGV.size < 1
  p "Usage: ruby history.rb /your/repo/directory branch(defaults to master)"
  exit
end

output_file = 'HISTORY.md'
repo_dir = ARGV[0]
branch = ARGV[1] || 'master'
output = "# #{File.basename(File.absolute_path(repo_dir))} - History\n"

repo = Grit::Repo.new(repo_dir)
head = Grit::Tag.new(repo.commits(branch).first.sha, repo, repo.commits(branch).first.id)
tags = repo.tags + [head]
tags.sort! {|x,y| y.commit.authored_date <=> x.commit.authored_date}

output << "## Tags\n"
tags.each do |tag|
  tag_name = tag.name
  if tag == tags.first
    tag_name = 'LATEST'
  end
  output << "* [#{tag_name} - #{tag.commit.authored_date.strftime("%-d %b, %Y")} (#{tag.commit.sha[0,8]})](##{tag_name})\n"
end

output << "\n## Details\n"
tagcount = 0
tags.each do |tag|
  tag_name = tag.name
  if tag == tags.first
    tag_name = 'LATEST'
  end
  output << "### <a name = \"#{tag_name}\">#{tag_name} - #{tag.commit.authored_date.strftime("%-d %b, %Y")} (#{tag.commit.sha[0,8]})\n\n"
  if (tagcount != tags.size - 1)
    commit_set = repo.commits_between(tags[tagcount + 1].name, tag.name)
    commit_set.sort! {|x,y| y.authored_date <=> x.authored_date }
    commit_set.each do |c|
      output << "* #{c.short_message} (#{c.sha[0,8]})\n\n"
      if c.short_message != c.message
        output << "\n```\n#{c.message.gsub(/```/, "\n")}\n```\n"
      end
    end
  else
    output << "* Initial release.\n"
  end
  tagcount += 1
end

File.open(output_file, 'w') { |f| f.write(output) }

puts "success, output sent to #{output_file}"

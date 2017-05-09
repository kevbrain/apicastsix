# Sometimes it's a README fix, or something like that - which isn't relevant for
# including in a project's CHANGELOG for example
declared_trivial = github.pr_title.include? "#trivial"

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
warn("PR is classed as Work in Progress") if github.pr_title.include? "[WIP]"

# Warn when there is a big PR
warn("Big PR") if git.lines_of_code > 500

has_app_changes = git.modified_files.grep(%r{apicast/}).any?
markdown_files = git.modified_files.grep(/\.md$/)

if !git.modified_files.include?("CHANGELOG.md") && has_app_changes && github.branch_for_base == 'master'
  fail("Please include a CHANGELOG entry. \nYou can find it at [CHANGELOG.md](https://github.com/3scale/apicast/blob/master/CHANGELOG.md).")
  message "Note, we hard-wrap at 80 chars and use 2 spaces after the last line."
end

ENV['LANG'] = 'en_US.utf8'

# Look for spelling issues
prose.ignored_words = %w(
  s2i openresty APIcast nameservers resty-resolver nginx Redis OAuth ENV backend 3scale OpenShift Default Lua
  hostname LRU cosocket TODO lua-resty-lrucache
)
prose.check_spelling markdown_files - %w(CHANGELOG.md)

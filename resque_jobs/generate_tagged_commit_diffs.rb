$LOAD_PATH.push("../") unless $LOAD_PATH.include?("../")
require "lib/script_environment"
require "resque"

class GenerateTaggedCommitDiffs
  @queue = :generate_tagged_commit_diffs
end

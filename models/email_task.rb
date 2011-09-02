# An email task which is queued up for future delivery.
# - failure_reason: the error message associated with this task's failure, if it's failed.
# - status: either "pending" or "failed". Failed tasks are kept around so that you can troubleshoot their
#   failure reason (usually a bad email config, or an email server which was down for awhile) and then reset
#   those pending tasks.
class EmailTask < Sequel::Model
  many_to_one :commit
end

# An email which has been sent. We'll use this for bookkeeping.
# NOTE(philc): This information may live better in a log file. For now, it's in a DB so that we can
# better monitor and troubleshoot failed emails.
# Columns:
# - failure_reason: the error message associated with this task's failure, if it's failed.
# - result: either "success" or "failure".
class CompletedEmail < Sequel::Model
  many_to_one :commit
end

# A container for work which should be processed in the background. The parameters for the job are serialized
# into JSON in the "params" column.
# Columns:
#   - job_type: a string identifying what kind of job this is.
#   - params: the parameters of the job, encoded as JSON.

require "json"

class BackgroundJob < Sequel::Model
  # The different job types.
  COMMENTS_EMAIL = "comments_email"

  # The parameters of this job. Deserializes the params column from a JSON string.
  def params
    @params ||= (JSON.parse(self.values[:params]) rescue nil)
  end
end
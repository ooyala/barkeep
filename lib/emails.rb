require "pony"
require "tilt"
require "lib/string_helper"
require "lib/git_diff_utils"

# Methods for sending various emails, like comment notifications and new commit notifications.
class Emails
  # This encapsulates some of the recoverable errors we have sending email, like the inability to connect
  # to the SMTP server.
  class RecoverableEmailError < StandardError
  end

  # Sends an email notification of a comment.
  # Upon success or non-recoverable failure, an entry in the completed_emails table is added to record the
  # email.
  def self.send_comment_email(commit, comments, send_immediately = false)
    grit_commit = commit.grit_commit
    subject = "Comments for #{grit_commit.id_abbrev} #{grit_commit.author.user.name} - " +
        "#{grit_commit.short_message[0..60]}"
    html_body = comment_email_body(commit, comments)

    # TODO(philc): Provide a plaintext email as well.

    all_previous_commenters = commit.comments.map { |comment| comment.user.email }
    to = ([commit.user.email] +
          users_with_saved_searches_matching(commit).map(&:email) +
          all_previous_commenters).uniq

    completed_email = CompletedEmail.new(:to => to.join(","), :subject => subject,
        :result => "success", :comment_ids => comments.map(&:id).join(","))

    begin
      deliver_mail(to.join(","), subject, html_body, pony_options_for_commit(commit))
    rescue Exception => error
      unless error.is_a?(RecoverableEmailError)
        completed_email.result = "failure"
        completed_email.failure_reason = "#{error.class} #{error.message}\n#{error.backtrace.join("\n")}"
        completed_email.save
      end
      raise error
    end

    completed_email.save
  end

  # Returns a list of User objects who have saved searches which match the given commit.
  # This can take up to 0.5 seconds per saved search, as it calls out to git for every repo tracked
  # unless the saved search limits by repo.
  def self.users_with_saved_searches_matching(commit)
    searches = SavedSearch.eager(:user).all
    searches_by_user = searches.group_by(&:user)
    users_with_matching_searches = searches_by_user.map do |user, searches|
      searches.any? { |search| search.matches_commit?(commit) } ? user : nil
    end
    users_with_matching_searches.compact
  end

  # Email headers which should be used when sending emails about a commit. This will help other emails
  # discussing this commit thread properly.
  # Returns a hash. You can pass this hash through to Pony via Pony.mail(..., :headers => headers )
  def self.pony_options_for_commit(commit)
    # See http://cr.yp.to/immhf/thread.html for information about headers used for threading.
    # To have Gmail properly thread all correspondences, you must use the same value for In-Reply-To
    # on all messages in the same thread. The message ID that In-Reply-To refers to need not exist.
    # Note that consumer Gmail (but not corporate Gmail for your domain) ignores any custom message-id
    # on the message and instead uses their own.

    # Strip off any port-numbers from the barkeep hostname. Gmail will not thread properly when the
    # In-Reply-To header has colons in it. It must just discard the header altogether.
    hostname_without_port = BARKEEP_HOSTNAME.sub(/\:.+/, "")
    message_id = "<#{commit.sha}-comments@#{hostname_without_port}>"
    {
      :headers => {
        "In-Reply-To" => message_id,
        "References" => message_id
      }
    }
  end

  # Sends an email using Pony.
  # pony_options: extra options to pass through to Pony. Used for setting mail headers like
  # "message-ID" to enable threading.
  def self.deliver_mail(to, subject, html_body, pony_options = {})
    options = { :to => to, :via => :smtp, :subject => subject, :html_body => html_body,
      # These settings are from the Pony documentation and work with Gmail's SMTP TLS server.
      :via_options => {
        :address => "smtp.gmail.com",
        :port => "587",
        :enable_starttls_auto => true,
        :user_name => GMAIL_USERNAME,
        :password => GMAIL_PASSWORD,
        :authentication => :plain,
        # the HELO domain provided by the client to the server
        :domain => "localhost.localdomain"
      }
    }
    begin
      Pony.mail(options.merge(pony_options))
    rescue Net::SMTPAuthenticationError => error
      # Gmail's SMTP server sometimes gives this response; we've seen it come up in the admin dashboard.
      if error.message.include?("Cannot authenticate due to temporary system problem")
        raise RecoverableEmailError.new(error.message)
      else
        raise error
      end
    rescue Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ETIMEDOUT => error
      raise RecoverableEmailError.new(error.message)
    end
  end

  # The email body for commit ingestion emails.
  def self.commit_email_body(commit)
    template = Tilt.new(File.join(File.dirname(__FILE__), "../views/email/commit_email.erb"))
    template.render(self, :commit => commit)
  end

  # The email body for comment emails.
  def self.comment_email_body(commit, comments)
    general_comments, file_comments = comments.partition(&:general_comment?)

    tagged_diffs = GitDiffUtils.get_tagged_commit_diffs(commit.git_repo.name, commit.grit_commit)

    diffs_by_file = tagged_diffs.group_by { |tagged_diff| tagged_diff[:file_name_after] }
    diffs_by_file.each { |filename, diffs| diffs_by_file[filename] = diffs.first }

    comments_by_file = file_comments.group_by { |comment| comment.commit_file.filename }
    comments_by_file.each { |filename, comments| comments.sort_by!(&:line_number) }

    template = Tilt.new(File.join(File.dirname(__FILE__), "../views/email/comment_email.erb"))
    locals = { :commit => commit, :comments_by_file => comments_by_file,
        :general_comments => general_comments,
        :diffs_by_file => diffs_by_file }
    template.render(self, locals)
  end

  #
  # Helpers for formatting the email views.
  #

  # Removes empty, unchanged lines from the edges of the given line_diffs array.
  # This is useful so that our diffs in emails don't have unnecessary whitespace around them.
  def self.strip_unchanged_blank_lines(line_diffs)
    line_diffs = line_diffs.dup
    until line_diffs.empty? do
      break unless (line_diffs.first.tag == :same && line_diffs.first.data.blank?)
      line_diffs.shift
    end
    until line_diffs.empty? do
      break unless (line_diffs.last.tag == :same && line_diffs.last.data.blank?)
      line_diffs.pop
    end
    line_diffs
  end

  # Returns the string that git log formats when you pass --stat to git log. It's a terse representation
  # of all files which have changed.
  def self.diff_stat(grit_repo, commit_sha)
    diff_stat_line_width = 90
    git_log_options = {
      :stat => diff_stat_line_width,
      :M => true, # detect renames.
      :n => 1,
      :pretty => "format:" # include no information except the diff stat.
    }
    output = grit_repo.git.log(git_log_options, [commit_sha])
    # Trim off the first line, which is blank because of our --pretty=format: argument.
    output.strip
  end
end

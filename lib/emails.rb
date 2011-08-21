require "pony"
require "tilt"
require "lib/string_helper"

# Methods for sending various emails, like comment notifications and new commit notifications.
class Emails
  LINES_OF_CONTEXT = 4

  # Enqueues an email notification of a comment for delivery.
  def self.send_comment_email(grit_commit, comments)
    subject = "Comments for #{grit_commit.id_abbrev} #{grit_commit.author.user.name} - " +
        "#{grit_commit.short_message[0..60]}"
    html_body = comment_email_body(grit_commit, comments)

    # TODO(philc): Provide a plaintext email as well.
    # TODO(philc): Determine how we're going to let this email FROM address be configured.
    # TODO(philc): Delay the emails and batch them together.
    EmailTask.create(:subject => subject, :to => "phil.crosby@gmail.com", :body => html_body)
  end

  def self.deliver_mail(to, subject, html_body)
    puts "Sending email to #{to} with subject \"#{subject}\""
    Pony.mail(:to => to, :via => :smtp, :subject => subject, :html_body => html_body,
      # These settings are from the Pony documentation and work with Gmail's TLS smtp server.
      :via_options => {
        :address => "smtp.gmail.com",
        :port => "587",
        :enable_starttls_auto => true,
        :user_name => GMAIL_USERNAME,
        :password => GMAIL_PASSWORD,
        :authentication => :plain,
        # the HELO domain provided by the client to the server
        :domain => "localhost.localdomain"
    })
  end

  def self.comment_email_body(grit_commit, comments)
    general_comments, file_comments = comments.partition(&:general_comment?)

    tagged_diffs = GitHelper.get_tagged_commit_diffs(grit_commit)

    diffs_by_file = tagged_diffs.group_by { |tagged_diff| tagged_diff[:file_name_after] }
    diffs_by_file.each { |filename, diffs| diffs_by_file[filename] = diffs.first }

    comments_by_file = file_comments.group_by { |comment| comment.commit_file.filename }
    comments_by_file.each { |filename, comments| comments.sort_by!(&:line_number) }

    template = Tilt.new(File.join(File.dirname(__FILE__), "../views/email/comment_email.erb"))
    locals = { :grit_commit => grit_commit, :comments_by_file => comments_by_file,
        :general_comments => general_comments,
        :diffs_by_file => diffs_by_file }
    template.render(self, locals)
  end

  #
  # Helpers for formatting the email views.
  #

  # An array of LineDiff objects which are close to the given line_number.
  # - line_diffs: an array of LineDiff objects
  def self.context_around_line(line_number, line_diffs)
    context = line_diffs.select do |line_diff|
      diff_line_number = (line_diff.tag == :removed ? line_diff.line_num_before : line_diff.line_num_after)
      (diff_line_number - line_number).abs <= LINES_OF_CONTEXT
    end
  end

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
end
require "pony"
require "tilt"
require "lib/string_helper"

# Methods for sending various emails, like comment notifications and new commit notifications.
class Emails
  def self.send_comment_email(grit_commit, comments)
    subject = "Comments for #{grit_commit.id_abbrev} #{grit_commit.author.user.name} - " +
        "#{grit_commit.short_message[0..60]}"
    html_body = comment_email_body

    # TODO(philc): Provide a plaintext email as well.
    # TODO(philc): Determine how we're going to let this email FROM address be configured.
    Pony.mail(:to => "phil.crosby@gmail.com", :from => "codereview@philisoft.com",
        :subject => subject, :html_body => html_body)
    html_body
  end

  def self.comment_email_body(grit_commit, comments)
    comments_grouped_by_file = comments.group_by { |comment| comment.commit_file.filename }
    comments_grouped_by_file.each { |filename, comments| comments.sort_by!(&:line_number) }


    template = Tilt.new(File.join(File.dirname(__FILE__), "../views/email/comment_email.erb"))
    locals = { :grit_commit => grit_commit, :comments_grouped_by_file => comments_grouped_by_file }
    template.render(self, locals)
  end
end
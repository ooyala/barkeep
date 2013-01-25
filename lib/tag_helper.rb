module TagHelper
  def self.get_label_and_class(current_user_id, comment)
    label_class = (current_user_id == comment.user_id) ? "fromMe" : "toMe"
    label = comment.state
    [label_class, label]
  end
end

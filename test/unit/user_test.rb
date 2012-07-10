require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))

class UserTest < Scope::TestCase
  context "validations" do

    context "invalid" do
      should "return FALSE for invalid object and contains invalid message" do
        @user = User.new(:saved_search_time_period => "string")
        assert !@user.valid?

        errors = @user.errors.fetch(:saved_search_time_period)
        assert errors.include?("is invalid")
      end

      should "not accept ['1', '3', '7', '14', '30'] for saved_search_time_period" do
        @user = User.new(:saved_search_time_period => '1')
        assert !@user.valid?
        @user = User.new(:saved_search_time_period => '3')
        assert !@user.valid?
        @user = User.new(:saved_search_time_period => '7')
        assert !@user.valid?
        @user = User.new(:saved_search_time_period => '14')
        assert !@user.valid?
        @user = User.new(:saved_search_time_period => '30')
        assert !@user.valid?
      end
    end

    context "valid" do
      should "accept nil for saved_search_time_period" do
        @user = User.new
        assert @user.valid?
      end

      should "accept [1, 3, 7, 14, 30, User::ONE_YEAR] for saved_search_time_period" do
        @user = User.new(:saved_search_time_period => 1)
        assert @user.valid?
        @user = User.new(:saved_search_time_period => 3)
        assert @user.valid?
        @user = User.new(:saved_search_time_period => 7)
        assert @user.valid?
        @user = User.new(:saved_search_time_period => 14)
        assert @user.valid?
        @user = User.new(:saved_search_time_period => 30)
        assert @user.valid?
        @user = User.new(:saved_search_time_period => User::ONE_YEAR)
        assert @user.valid?
      end
    end
  end
end
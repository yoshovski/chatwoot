# Super Admin "New accounts" (T11): every public signup, newest first, with abuse flags.
class SuperAdmin::NewAccountsController < SuperAdmin::ApplicationController
  def index
    @flagged_only = params[:flagged] == '1'
    @page = [params[:page].to_i, 1].max
    @report = Signup::NewAccountsReport.new(page: @page, flagged_only: @flagged_only)
  end
end

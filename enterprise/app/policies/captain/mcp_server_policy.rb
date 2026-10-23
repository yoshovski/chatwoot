class Captain::McpServerPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def sync?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end
end

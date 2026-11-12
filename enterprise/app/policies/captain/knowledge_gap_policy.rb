class Captain::KnowledgeGapPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def answer?
    true
  end

  def dismiss?
    true
  end

  def topics?
    true
  end

  def action_requests?
    true
  end

  def bulk_dismiss?
    true
  end
end

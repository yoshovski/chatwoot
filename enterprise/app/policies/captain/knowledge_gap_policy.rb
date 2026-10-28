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
end

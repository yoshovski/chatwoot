# How long Captain waits for Dify to index an upload. Dify works through uploads one by one, so a
# large website import can queue for an hour; polls start fast and back off to about two hours.
module Captain::Dify::IndexingSchedule
  STEPS = [[24, 5.seconds], [56, 30.seconds], [45, 2.minutes]].freeze
  MAX_POLLS = STEPS.sum(&:first)

  def self.wait(poll)
    remaining = poll
    STEPS.each do |count, wait|
      return wait if remaining < count

      remaining -= count
    end
    STEPS.last.last
  end
end

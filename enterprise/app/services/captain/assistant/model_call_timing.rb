# RubyLLM recursively completes after tools; each provider request gets its own start timestamp.
module Captain::Assistant::ModelCallTiming
  def self.install(runner)
    runner.on_chat_created do |chat, *_args|
      chat.singleton_class.prepend(self) unless chat.is_a?(self)
    end
  end

  def complete(...)
    previous = @captain_inference_started_at
    @captain_inference_started_at = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
    super
  ensure
    @captain_inference_started_at = previous
  end
end

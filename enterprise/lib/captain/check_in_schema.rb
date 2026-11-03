class Captain::CheckInSchema < RubyLLM::Schema
  string :text, description: 'One short check-in for the visitor, in their language'
end

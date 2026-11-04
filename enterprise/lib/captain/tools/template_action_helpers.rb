# Validation and wording shared by the actions that send an email template.
module Captain::Tools::TemplateActionHelpers
  def template_errors(assistant, key)
    Captain::EmailTemplates.new(assistant).find(key) ? [] : ["no email template #{key}"]
  end

  def template_name(assistant, key) = Captain::EmailTemplates.new(assistant).name(key)
end

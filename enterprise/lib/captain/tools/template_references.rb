# The variables a Liquid template reads, checked against what an action step can see: the tool's params,
# `outputs.<key>` of earlier steps and `contact.<field>`. Loop and assign variables defined in the template count too.
class Captain::Tools::TemplateReferences
  def initialize(template)
    @template = Liquid::Template.parse(template, error_mode: :strict)
  end

  def unknown(params:, outputs:, contact_fields:)
    known_roots = params + variables_of(Liquid::For, Liquid::Assign) + ['forloop']
    known_children = { 'outputs' => outputs, 'contact' => contact_fields }
    lookups.filter_map do |root, child|
      next if known_roots.include?(root) || known_children[root]&.include?(child)

      [root, child].compact.join('.')
    end.uniq
  end

  private

  def lookups
    visitor = Liquid::ParseTreeVisitor.for(@template.root)
    visitor.add_callback_for(Liquid::VariableLookup) { |node| { path: [node.name.to_s, node.lookups.first&.to_s] } }
    collect(visitor.visit)
  end

  def variables_of(*classes)
    visitor = Liquid::ParseTreeVisitor.for(@template.root)
    classes.each { |klass| visitor.add_callback_for(klass) { |node| { path: [node.respond_to?(:variable_name) ? node.variable_name : node.to] } } }
    collect(visitor.visit).map(&:first)
  end

  # visit returns nested [item, children] pairs; callbacks return a hash so the visitor does not destructure it.
  def collect(tree)
    tree.flat_map do |item, children|
      (item.is_a?(Hash) ? [item[:path]] : []) + collect(children)
    end
  end
end

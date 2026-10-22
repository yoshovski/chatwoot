require 'rails_helper'

RSpec.describe Captain::Knowledge::OpenApiMarkdown do
  let(:spec) do
    {
      'openapi' => '3.0.0',
      'security' => [{ 'bearer' => [] }],
      'components' => {
        'securitySchemes' => { 'bearer' => { 'type' => 'http', 'scheme' => 'bearer' } },
        'schemas' => { 'Status' => { 'type' => 'string', 'enum' => %w[active paused] } }
      },
      'paths' => {
        '/subscriptions/{id}' => {
          'parameters' => [{ 'name' => 'id', 'in' => 'path', 'required' => true, 'schema' => { 'type' => 'string' } }],
          'get' => {
            'summary' => 'Get a subscription',
            'description' => "Returns one subscription.\n\n# Errors\n\nUnknown ids return 404.",
            'parameters' => [{ 'name' => 'Accept', 'in' => 'header', 'schema' => { 'type' => 'string' } }],
            'responses' => {
              '200' => { 'description' => 'OK', 'content' => { 'application/json' => { 'schema' => {
                'allOf' => [{ 'properties' => { 'status' => { '$ref' => '#/components/schemas/Status' } } },
                            { 'properties' => { 'items' => { 'type' => 'array',
                                                             'items' => { 'properties' => { 'sku' => { 'type' => 'string',
                                                                                                       'example' => 'A1' } } } } } }]
              } } } }
            }
          }
        }
      }
    }
  end

  it 'replaces an OpenAPI block with one readable section per operation' do
    markdown = described_class.convert("# Subscriptions\n\n## OpenAPI definition\n\n```json\n#{spec.to_json}\n```\n")

    expect(markdown).to include(
      "## GET /subscriptions/{id}: Get a subscription\n\nEndpoint: `GET /subscriptions/{id}`. Authentication: HTTP bearer.",
      "### Errors\n\nUnknown ids return 404.",
      '| id | path | string | yes |  |',
      '### Response 200: OK',
      '| status | string | One of: active, paused. |',
      '| items[].sku | string | Example: A1. |'
    )
    expect(markdown).not_to include('OpenAPI definition', '| Accept |', '$ref')
  end

  it 'leaves other code blocks untouched' do
    markdown = "```json\n{\"customerId\": 1}\n```"

    expect(described_class.convert(markdown)).to eq(markdown)
  end
end

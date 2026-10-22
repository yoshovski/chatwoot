require 'rails_helper'

RSpec.describe Captain::Knowledge::HtmlTables do
  it 'turns an MDX table spread over many lines into a pipe table' do
    markdown = <<~MARKDOWN
      Intro.

      <Table align={["left","left"]}>
        <thead>
          <tr>
            <th>Payment method</th>

            <th>What to provide</th>
          </tr>
        </thead>

        <tbody>
          <tr>
            <td>
              Card
            </td>

            <td>
              A list of origins with `https://` for production.
            </td>
          </tr>
        </tbody>
      </Table>
    MARKDOWN

    expect(described_class.convert(markdown)).to eq(<<~MARKDOWN)
      Intro.

      | Payment method | What to provide |
      | --- | --- |
      | Card | A list of origins with `https://` for production. |
    MARKDOWN
  end
end

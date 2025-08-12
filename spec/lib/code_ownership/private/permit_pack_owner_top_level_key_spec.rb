# frozen_string_literal: true

RSpec.describe CodeOwnership::Private::PackOwnershipValidator do
  it 'permits the owner top-level key' do
    expect(described_class.new.permitted_keys).to include('owner')
  end
end

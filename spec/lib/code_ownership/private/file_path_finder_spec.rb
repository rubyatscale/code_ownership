# frozen_string_literal: true

RSpec.describe CodeOwnership::Private::FilePathFinder do
  class TestClass; end # rubocop:disable Lint/ConstantDefinitionInBlock, Lint/EmptyClass

  describe '.path_from_klass' do
    subject do
      described_class.path_from_klass(klass)
    end

    let(:klass) do
      TestClass
    end

    context 'when the klass is a class' do
      it 'returns the path to the class' do
        expect(subject).to include('spec/lib/code_ownership/private/file_path_finder_spec.rb')
      end
    end

    context 'when NameError is raised' do
      before do
        allow(Object).to receive(:const_source_location).and_raise(NameError)
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when the klass is nil' do
      let(:klass) { nil }

      it 'raises an ArgumentError' do
        expect(subject).to be_nil
      end
    end
  end

  describe '.from_backtrace' do
    subject(:files) { described_class.from_backtrace(backtrace).to_a }

    context 'when backtrace is nil' do
      let(:backtrace) { nil }

      it 'returns an empty array' do
        expect(files).to eq([])
      end
    end

    context 'when backtrace is empty' do
      let(:backtrace) { [] }

      it 'returns an empty array' do
        expect(files).to eq([])
      end
    end

    context 'on Ruby < 3.4 backtrace format (backticks)' do
      let(:backtrace) do
        ["./app/models/user.rb:12:in `save'", "app/controllers/some_controller.rb:43:in `block (2 levels) in create'"]
      end

      it 'extracts file paths' do
        if RUBY_VERSION < '3.4.0'
          expect(files).to include('app/models/user.rb', 'app/controllers/some_controller.rb')
        else
          skip 'Ruby version >= 3.4 uses single quote backtrace format'
        end
      end
    end

    context 'on Ruby >= 3.4 backtrace format (single quotes)' do
      let(:backtrace) do
        ["./app/models/user.rb:12:in 'save'", "app/controllers/some_controller.rb:43:in 'block (2 levels) in create'"]
      end

      it 'extracts file paths' do
        if RUBY_VERSION >= '3.4.0'
          expect(files).to include('app/models/user.rb', 'app/controllers/some_controller.rb')
        else
          skip 'Ruby version < 3.4 does not use single quote backtrace format'
        end
      end
    end
  end
end

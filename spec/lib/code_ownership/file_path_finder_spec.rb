# frozen_string_literal: true

RSpec.describe CodeOwnership::FilePathFinder do
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
        expect(subject).to include('spec/lib/code_ownership/file_path_finder_spec.rb')
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
end

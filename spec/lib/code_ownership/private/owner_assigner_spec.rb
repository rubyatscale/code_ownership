module CodeOwnership
  RSpec.describe Private::OwnerAssigner do
    describe '.assign_owners' do
      subject(:assign_owners) { described_class.assign_owners(globs_to_owning_team_map) }

      let(:team_1) { instance_double(CodeTeams::Team) }
      let(:team_2) { instance_double(CodeTeams::Team) }

      let(:globs_to_owning_team_map) do
        {
          'app/services/[test]/some_other_file.ts' => team_1,
          'app/services/withoutbracket/file.ts' => team_2,
          'app/models/*.rb' => team_2
        }
      end

      before do
        write_file('app/services/[test]/some_other_file.ts', <<~YML)
          // @team Bar
        YML

        write_file('app/services/withoutbracket/file.ts', <<~YML)
          // @team Bar
        YML
      end

      it 'returns a hash with the same keys and the values that are files' do
        expect(assign_owners).to eq(
          'app/services/[test]/some_other_file.ts' => team_1,
          'app/services/withoutbracket/file.ts' => team_2
        )
      end

      context 'when file name includes square brackets' do
        let(:globs_to_owning_team_map) do
          {
            'app/services/[test]/some_other_[test]_file.ts' => team_1
          }
        end

        before do
          write_file('app/services/[test]/some_other_[test]_file.ts', <<~YML)
            // @team Bar
          YML

          write_file('app/services/t/some_other_e_file.ts', <<~YML)
            // @team Bar
          YML
        end

        it 'matches the glob pattern' do
          expect(assign_owners).to eq(
            'app/services/[test]/some_other_[test]_file.ts' => team_1,
            'app/services/t/some_other_e_file.ts' => team_1
          )
        end
      end

      context 'when glob pattern also exists' do
        before do
          write_file('app/services/t/some_other_file.ts', <<~YML)
            // @team Bar
          YML
        end

        it 'also matches the glob pattern' do
          expect(assign_owners).to eq(
            'app/services/[test]/some_other_file.ts' => team_1,
            'app/services/t/some_other_file.ts' => team_1,
            'app/services/withoutbracket/file.ts' => team_2
          )
        end
      end

      context 'when * is used in glob pattern' do
        before do
          write_file('app/models/some_file.rb', <<~YML)
            // @team Bar
          YML

          write_file('app/models/nested/some_file.rb', <<~YML)
            // @team Bar
          YML
        end

        it 'also matches the glob pattern' do
          expect(assign_owners).to eq(
            'app/services/[test]/some_other_file.ts' => team_1,
            'app/services/withoutbracket/file.ts' => team_2,
            'app/models/some_file.rb' => team_2
          )
        end
      end
    end
  end
end

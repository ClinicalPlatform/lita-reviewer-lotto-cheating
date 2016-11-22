# frozen_string_literal: true

require 'spec_helper'
require 'lita/handlers/reviewer_lotto_cheating/error'
require 'lita/handlers/reviewer_lotto_cheating/selector'

describe Lita::Handlers::ReviewerLottoCheating::Selector, model: true do
  describe '.call' do
    subject { described_class.call(*arguments) }
    let (:arguments) { [100] }

    context 'when no reviewer candidation' do
      it 'raise Error' do
        expect { subject }.to raise_error(APP::Error)
      end
    end

    context 'when reviewer candidations exist' do
      before do
        APP::User.upsert(name: 'test1', level: 1, working_days: (1..7).to_a)
        APP::User.upsert(name: 'test2', level: 2, working_days: (1..7).to_a)
      end
      it 'return 2 reviwers' do
        expect(subject.map(&:name)).to contain_exactly('test1', 'test2')
      end
    end
  end

  describe '#select' do
    let (:senior1) { UserMock.new('senior1', 2, [1, 2, 3, 4, 5]) }
    let (:senior2) { UserMock.new('senior2', 2, [1, 2, 3, 4 ,5]) }
    let (:junior1) { UserMock.new('junior1', 1, [1, 2, 3, 4, 5]) }
    let (:junior2) { UserMock.new('junior2', 1, [1, 2, 3, 4, 5]) }
    let (:users) { [ senior1, senior2, junior1, junior2 ] }

    subject { described_class.send(:select, users, user_points) }

    # ignore randomness
    before do
      allow(described_class).to receive(:rand).and_return(0)
    end

    context 'when all users have same working_days' do
      context 'with a user of the least reviewd count' do
        let(:user_points) do
          { 'senior1' => 2, 'senior2' => 5, 'junior1' => 3, 'junior2' => 2 }
        end

        it 'select its user' do
          expect(subject).to eq [senior1, junior2]
        end
      end

      context 'with multiple users of the same least reviewed count' do
        let(:user_points) do
          { 'senior1' => 2, 'senior2' => 5, 'junior1' => 2, 'junior2' => 2 }
        end

        it 'select the either of the users' do
          expect(subject).to eq([senior1, junior1]) | eq([senior1, junior2])
        end
      end
    end

    context 'when some users have different working_days' do
      let (:senior_parttime) { UserMock.new('senior_parttime', 2, [1, 2, 3]) }
      let (:junior_parttime) { UserMock.new('junior_parttime', 1, [1, 2]) }
      let (:users) { [ senior1, senior2, senior_parttime, junior1, junior2, junior_parttime ] }

      let(:user_points) do
        { 'senior1' => 4, 'senior2' => 5, 'senior_parttime' => 3,
          'junior1' => 6, 'junior2' => 6, 'junior_parttime' => 2 }
      end

      it 'select reviewers by cosidering working_days in a week' do
        expect(subject).to eq [senior1, junior_parttime]
      end
    end

    context 'with no senior reviewer' do
      let (:users) { [ junior1, junior2 ] }
      let(:user_points) do
        { 'junior1' => 2, 'junior2' => 3 }
      end

      it 'return only 1 reviewer' do
        expect(subject).to eq [junior1]
      end
    end

    context 'with no reviewer' do
      let (:users) { [] }
      let(:user_points) { {} }

      it { is_expected.to eq [] }
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'lita/handlers/reviewer_lotto_cheating/error'
require 'lita/handlers/reviewer_lotto_cheating/selector'

describe Lita::Handlers::ReviewerLottoCheating::Selector, model: true do
  describe '.call' do
    subject { described_class.call(arguments) }
    let (:arguments) { { users: users, duration: 100 } }

    context 'when no reviewer candidation' do
      let(:users) { [] }
      it 'raise Error' do
        expect { subject }.to raise_error(APP::Error)
      end
    end

    context 'when reviewer candidations exist' do
      let(:users) { [ UserMock.new('test1', 1, [1, 2, 3, 4, 5]),
                      UserMock.new('test2', 2, [1, 2, 3, 4, 5]) ] }
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
    let (:random_weight) { nil }

    subject { described_class.send(:select, users, user_points, random_weight: random_weight) }

    # ignore randomness
    before do
      allow(described_class).to receive(:rand).and_return(0)
    end

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

    context 'with no senior reviewer' do
      let (:users) { [ junior1, junior2 ] }
      let(:user_points) do
        { 'junior1' => 2, 'junior2' => 3, 'junior3' => 4 }
      end

      it 'return 2 reviewers from juniors' do
        expect(subject).to eq [junior1, junior2]
      end
    end

    context 'with no reviewer' do
      let (:users) { [] }
      let(:user_points) { {} }

      it { is_expected.to eq [] }
    end

    context 'when specifying random_weight' do
      let(:user_points) do
        { 'senior1' => 2, 'senior2' => 5, 'junior1' => 3, 'junior2' => 2 }
      end
      before do
        allow(described_class).to receive(:rand).and_return(100, 40, 40, 90)
      end

      context 'with random_weight 0' do
        let(:random_weight) { 0 }
        it 'return senior1, junior2' do
          expect(subject).to eq [senior1, junior2]
        end
      end

      # case senior1 point < senior2 point
      context 'with random_weight 49' do
        let(:random_weight) { 49 }
        it 'return senior1, junior2' do
          expect(subject).to eq [senior1, junior1]
        end
      end

      # case senior1 point == senior2 point
      context 'with random_weight 50' do
        let(:random_weight) { 50 }
        it 'return senior1, junior1' do
          expect(subject).to eq [senior1, junior1]
        end
      end

      # case senior1 point > senior2 point
      context 'with random_weight 51' do
        let(:random_weight) { 51 }
        it 'return senior2, junior1' do
          expect(subject).to eq [senior2, junior1]
        end
      end

      context 'with random_weight 100' do
        let(:random_weight) { 100 }
        it 'return senior2, junior1' do
          expect(subject).to eq [senior2, junior1]
        end
      end
    end
  end
end

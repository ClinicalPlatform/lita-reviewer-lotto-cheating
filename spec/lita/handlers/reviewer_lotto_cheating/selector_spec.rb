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
        expect { subject }.to raise_error(NS::Error)
      end
    end

    context 'when reviewer candidations exist' do
      before do
        NS::User.add_or_update(name: 'test1', level: 1, working_days: (1..7).to_a)
        NS::User.add_or_update(name: 'test2', level: 2, working_days: (1..7).to_a)
      end
      it 'return 2 reviwers' do
        expect(subject.map(&:name)).to contain_exactly('test1', 'test2')
      end
    end
  end

  describe '#select' do
    let (:senior1) { UserMock.new('senior1', 2) }
    let (:senior2) { UserMock.new('senior1', 2) }
    let (:junior1) { UserMock.new('junior1', 1) }
    let (:junior2) { UserMock.new('junior2', 1) }
    let (:users) { [ senior1, senior2, junior1, junior2 ] }

    subject { described_class.send(:select, users, user_points) }

    context 'with a user has done the least number of reviews' do
      let(:user_points) do
        { 'senior1' => 2, 'senior2' => 5, 'junior1' => 3, 'junior2' => 2 }
      end

      it 'select its user' do
        expect(subject).to eq [senior1, junior2]
      end
    end

    context 'with multiple users has done the least number of reviews' do
      let(:user_points) do
        { 'senior1' => 2, 'senior2' => 5, 'junior1' => 2, 'junior2' => 2 }
      end

      it 'select randomly between these users' do
        expect(subject).to eq([senior1, junior1]) | eq([senior1, junior2])
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

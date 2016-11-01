# frozen_string_literal: true

require 'spec_helper'
require 'lita/handlers/reviewer_lotto_cheating/error'
require 'lita/handlers/reviewer_lotto_cheating/selector'

describe Lita::Handlers::ReviewerLottoCheating::Selector, model: true do
  let(:selector) do
    described_class.new(logger: Lita.logger)
  end

  describe '#call' do
    subject { selector.call(*arguments) }
    let (:arguments) { [100] }

    context 'when no reviewer candidation' do
      it 'raise Error' do
        expect { subject }.to \
          raise_error(Lita::Handlers::ReviewerLottoCheating::Error)
      end
    end

    context 'when reviewer candidations exist' do
      before do
        NS::User.add(name: 'test1', level: 1, working_days: (1..7).to_a)
        NS::User.add(name: 'test2', level: 2, working_days: (1..7).to_a)
      end
      it 'return 2 reviwers' do
        expect(subject.map(&:name)).to contain_exactly('test1', 'test2')
      end
    end
  end
end


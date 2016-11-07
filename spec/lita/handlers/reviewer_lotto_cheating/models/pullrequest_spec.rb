# frozen_string_literal: true

require 'spec_helper'
require 'lita/handlers/reviewer_lotto_cheating/models/pullrequest'

describe Lita::Handlers::ReviewerLottoCheating::Pullrequest, model: true do
  describe '.list' do
    subject do
      VCR.use_cassette('foobar/test1/pulls') do
        described_class.list('foobar/test1')
      end
    end

    it 'fetch pullrequests' do
      expect(subject.map(&:id)).to eq [90730338, 90553639, 90553293, 90544452]
      expect(subject.first).to be_a \
        Lita::Handlers::ReviewerLottoCheating::Pullrequest
    end
  end
end

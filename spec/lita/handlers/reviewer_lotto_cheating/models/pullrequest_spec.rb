# frozen_string_literal: true

require 'spec_helper'
require 'lita/handlers/reviewer_lotto_cheating/models/pullrequest'

describe Lita::Handlers::ReviewerLottoCheating::Pullrequest, model: true do
  let (:pullrequest) do
    github = described_class.github
    VCR.use_cassette('foobar/test1/pull/3') do
      data = github.pull_request('foobar/test1', 3)
      described_class.new(data)
    end
  end

  describe '#assigned?' do
    subject { pullrequest.assigned? }

    context 'when not assigned' do
      it { is_expected.to be_falsy }
    end

    context 'when has been assigned' do
      before do
        described_class.redis.sadd(
          NS::Pullrequest::PULLREQUESTS_KEY, pullrequest.id
        )
      end
      it { is_expected.to be_truthy }
    end
  end

  describe '#key' do
    subject { pullrequest.send(:key) }
    it { is_expected.to eq 'pullrequests:/foobar/test1/pull/3' }
  end

  describe '#latest_commit' do
    subject { pullrequest.latest_commit }
    it { is_expected.to eq '486f6f44465c1a90695f686742f75f9260a34034' }
  end

  describe '#path' do
    subject { pullrequest.path }
    it { is_expected.to eq '/foobar/test1/pull/3' }
  end

  describe '#repo' do
    subject { pullrequest.repo }
    it { is_expected.to eq 'foobar/test1' }
  end

  describe '#save' do
    subject do
      pullrequest.save([
        UserMock.new('user1', 1),
        UserMock.new('user2', 2),
      ])
    end

    it 'save data properly to redis' do
      expect { subject }.to \
        change {
          Lita.redis.sismember('pullrequests', pullrequest.id)
        }.from(be_falsy).to(be_truthy).and \
        change {
          Lita.redis.zrange('pullrequests_ordered', 0, -1)
        }.from([]).to(['pullrequests:/foobar/test1/pull/3']).and \
        change {
          Lita.redis.smembers('pullrequests:/foobar/test1/pull/3')
        }.from([]).to(contain_exactly('user1', 'user2'))
    end
  end

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

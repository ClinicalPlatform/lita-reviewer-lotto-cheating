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
      before { described_class.redis.sadd('pullrequests', pullrequest.id) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#key' do
    subject { pullrequest.key }
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
      expect(subject.first).to be_a described_class
    end
  end

  describe '.calc_review_counts' do
    subject { described_class.calc_review_counts(duration: 365 * 24 * 60 * 60) }

    context 'with some reviewed pullrequests' do
      before do
        redis = described_class.redis

        keys = [
          'pullrequests:/foobar/test1/pull/1',
          'pullrequests:/foobar/test1/pull/2',
          'pullrequests:/foobar/test1/pull/3',
          'pullrequests:/foobar/test1/pull/4',
        ]
        redis.sadd(keys[0], ['user1', 'user2'])
        redis.sadd(keys[1], ['user1', 'user3'])
        redis.sadd(keys[2], ['user1', 'user4'])
        redis.sadd(keys[3], ['user2', 'user4'])

        redis.zadd('pullrequests_ordered', Time.now.to_i, keys[0])
        redis.zadd('pullrequests_ordered', Time.now.to_i, keys[1])
        redis.zadd('pullrequests_ordered', Time.now.to_i, keys[2])
        redis.zadd('pullrequests_ordered', Time.now.to_i, keys[3])
      end

      it 'return hash of each user reviewed count' do
        expect(subject).to eq({
          'user2' => 2,
          'user1' => 3,
          'user3' => 1,
          'user4' => 2,
        })
      end
    end

    context 'with no reviewed pullrequest' do
      it 'return empty hash' do
        expect(subject).to eq({})
      end
    end
  end
end

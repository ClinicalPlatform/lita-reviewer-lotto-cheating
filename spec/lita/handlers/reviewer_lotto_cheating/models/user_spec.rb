# frozen_string_literal: true

require 'spec_helper'
require 'lita/handlers/reviewer_lotto_cheating/models/user'

describe Lita::Handlers::ReviewerLottoCheating::User, model: true do
  let(:user) do
    described_class.new(name: 'test', level: 1, working_days: [1, 2, 3])
  end

  describe '#delete' do
    subject { user.delete }
    before { user.save }

    it 'delete user data from redis' do
      expect { subject }.to change {
        Lita.redis.keys('users:*').size
      }.from(be > 0).to(0)
    end
  end

  describe '#exist?' do
    subject { user.exist? }

    context 'when user does not exists' do
      it { is_expected.to be_falsy }
    end

    context 'when user exists' do
      before do
        Lita.redis.sadd('users', 'test')
      end
      it { is_expected.to be_truthy }
    end
  end

  describe '#key' do
    subject { user.key(*arguments) }

    context 'with "field"' do
      let(:arguments) { ['field'] }
      it { is_expected.to eq 'users:test:field' }
    end

    context 'without arguments' do
      let(:arguments) { nil }
      it { is_expected.to eq 'users:test' }
    end
  end

  describe '#level' do
    subject { user.level }

    let(:user) do
      described_class.new(name: 'test')
    end

    context 'with no value in redis' do
      before do
        Lita.redis.del('users:test:level')
      end
      it { is_expected.to eq 0 }
    end

    context 'with the value in redis' do
      before do
        Lita.redis.set('users:test:level', 3)
      end
      it { is_expected.to eq 3 }
    end
  end

  describe '#save' do
    subject { user.save }

    context 'when success' do
      it 'save user data to redis' do
        expect { subject }.to change {
          [ Lita.redis.get('users:test:level'),
            Lita.redis.smembers('users:test:working_days'), ]
        }.from([ nil, [] ])
          .to([ '1', %w(1 2 3) ])
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#update' do
    subject { user.update(level: 5) }

    context 'when success to save' do
      it 'udpate user data and save to redis' do
        expect(user).to receive(:save).and_return(true)
        expect { subject }.to change { user.level }.from(1).to(5)
        expect(subject).to be_truthy
      end
    end

    context 'when fail to save' do
      before do
        allow(user).to receive(:save).and_return(false)
      end
      it { is_expected.to be_falsy }
    end
  end

  describe '#working_days' do
    subject { user.working_days }

    let(:user) do
      described_class.new(name: 'test')
    end

    context 'with no value in redis' do
      before do
        Lita.redis.del('users:test:working_days')
      end
      it { is_expected.to eq [] }
    end

    context 'with the value in redis' do
      before do
        Lita.redis.sadd('users:test:working_days', [1, 2, 3])
      end
      it { is_expected.to eq [1, 2, 3] }
    end
  end

  describe '.upsert' do
    let(:args) { { name: 'test', level: 5, working_days: [1] } }
    subject { APP::User.upsert(args) }

    context 'when user exists' do
      before { user.save }

      it 'update the user info' do
        expect { subject }.to \
          change {
            APP::User.new(name: 'test').level
          }.from(1).to(5).and \
          change {
            APP::User.new(name: 'test').working_days
          }.from([1, 2, 3]).to([1])
      end
    end

    context 'when user does not exist' do
      it 'create new user' do
        expect(user.exist?).to be_falsy
        subject
        expect(user.exist?).to be_truthy
        expect(APP::User.new(name: 'test').level).to eq 5
        expect(APP::User.new(name: 'test').working_days).to eq [1]
      end
    end
  end

  describe '.list' do
    subject { described_class.list }

    context 'with no user in redis' do
      it { is_expected.to eq [] }
    end

    context 'with users in redis' do
      before do
        Lita.redis.sadd('users', %w(test1 test2 test3))
      end
      it do
        expect(subject.map(&:name)).to contain_exactly(*%w(test1 test2 test3))
      end
    end
  end

  describe '.reviewer_candidates' do
    subject { described_class.reviewer_candidates(*arguments) }
    before do
      # Fixed current week day to monday => working_day = 1
      Timecop.freeze(Time.local(2017, 1, 23))
      # register user list
      Lita.redis.sadd('users', %w(test1 test2 test3))
    end

    context 'when all users are on working_days' do
      before do
        described_class.new(name: 'test1', level: 1, working_days: [1, 2, 3, 4, 5]).save
        described_class.new(name: 'test2', level: 2, working_days: [1, 2, 3, 4, 5]).save
        described_class.new(name: 'test3', level: 2, working_days: [1, 2, 3, 4, 5]).save
      end
      let(:arguments) { [] }
      it { expect(subject.map(&:name)).to contain_exactly(*%w(test1 test2 test3)) }
    end

    context 'when some users are not on working_days' do
      before do
        described_class.new(name: 'test1', level: 1, working_days: [1, 2, 3, 4, 5]).save
        described_class.new(name: 'test2', level: 2, working_days: [2, 3]).save
        described_class.new(name: 'test3', level: 2, working_days: [1, 2, 3]).save
      end

      let(:arguments) { [] }
      it { expect(subject.map(&:name)).to contain_exactly(*%w(test1 test3)) }
    end

    context 'with exclude_users' do
      before do
        described_class.new(name: 'test1', level: 1, working_days: [1, 2, 3, 4, 5]).save
        described_class.new(name: 'test2', level: 2, working_days: [1, 2, 3, 4, 5]).save
        described_class.new(name: 'test3', level: 2, working_days: [1, 2, 3, 4, 5]).save
      end

      let(:arguments) { ['test1'] }
      it { expect(subject.map(&:name)).to contain_exactly(*%w(test2 test3)) }
    end
  end


  describe '.find' do
    subject { described_class.find(user.name) }

    context 'when user exists' do
      before { user.save }

      it 'return the user' do
        expect(subject.name).to eq user.name
        expect(subject.level).to eq user.level
        expect(subject.working_days).to eq user.working_days
      end
    end

    context 'when user does not exists' do
      let(:user) { APP::User.new(name: 'no_such_user') }
      it { is_expected.to be_nil }
    end
  end
end

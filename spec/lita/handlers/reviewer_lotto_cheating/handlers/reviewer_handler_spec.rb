require 'spec_helper'

describe Lita::Handlers::ReviewerLottoCheating::ReviewerHandler, lita_handler: true do
  describe 'route' do
    context 'reviewer' do
      context 'with valid argument' do
        it do
          is_expected.to \
            route_command('reviewer http://www.example.com/')
            .to(:assign_reviewers_from_chat)
        end
      end

      context 'with invalid argument' do
        it do
          is_expected.not_to \
            route_command('reviewer hoge')
            .to(:assign_reviewers_from_chat)
        end
      end

      context 'without arguments' do
        it do
          is_expected.not_to \
            route_command('reviewer')
            .to(:assign_reviewers_from_chat)
        end
      end

      context 'when not command' do
        it do
          is_expected.not_to \
            route('reviewer http://www.example.com/')
            .to(:assign_reviewers_from_chat)
        end
      end
    end
  end

  describe 'reviewer GITHUB_PR_URL' do
    shared_context 'environment for reviewer command' do
      let(:config) { Struct.new(:chat_target).new({ room: '#general' }) }

      before do
        APP::User.upsert(name: 'test1', level: 1, working_days: (0..5).to_a)
        APP::User.upsert(name: 'test2', level: 2, working_days: (0..5).to_a)

        allow_any_instance_of(APP::ReviewerHandler).to \
          receive(:responders).and_return([
            APP::ChatResponder.new(robot: robot, config: config)
        ])
      end
    end

    subject { replies.last }

    context 'with non http(s) URL' do
      before do
        send_command('reviewer ftp://github.com/foobar/test1/pull/3')
      end
      it do
        is_expected.to eq \
          "Error: 'ftp://github.com/foobar/test1/pull/3' is not github pullrequest URL."
      end
    end

    context 'with non pullrequest URL' do
      before do
        send_command('reviewer https://github.com/foobar/test1/pul')
      end
      it do
        is_expected.to eq \
          "Error: 'https://github.com/foobar/test1/pul' is not github pullrequest URL."
      end
    end

    context 'with non existing pullrequest' do
      include_context 'environment for reviewer command'

      before do
        VCR.use_cassette('foobar/test1/pull/9999') do
          send_command('reviewer https://github.com/foobar/test1/pull/9999')
        end
      end

      it { is_expected.to include '404 - Not Found' }
    end

    context 'with valid pullrequest' do
      include_context 'environment for reviewer command'

      before do
        VCR.use_cassette('foobar/test1/pull/3') do
          send_command('reviewer https://github.com/foobar/test1/pull/3')
        end
      end

      it do
        is_expected.to eq \
          '@test2, @test1 are assigned as the reviewers for https://github.com/foobar/test1/pull/3!!'
      end

      context 'and send same reviewer command again' do
        before do
          VCR.use_cassette('foobar/test1/pull/3') do
            send_command('reviewer https://github.com/foobar/test1/pull/3')
          end
        end
        it { is_expected.to eq 'https://github.com/foobar/test1/pull/3 has been already assigned reviewers.' }
      end
    end
  end
end


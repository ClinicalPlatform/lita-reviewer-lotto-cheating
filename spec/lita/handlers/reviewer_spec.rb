require "spec_helper"

describe Lita::Handlers::ReviewerLottoCheating, lita_handler: true do
  describe 'route' do
    context 'reviewer' do
      context 'with valid argument' do
        it { is_expected.to route_command('reviewer http://www.example.com/').to(:lookup_reviewers) }
      end

      context 'with invalid argument' do
        it { is_expected.not_to route_command('reviewer hoge').to(:lookup_reviewers) }
      end

      context 'without arguments' do
        it { is_expected.not_to route_command('reviewer').to(:lookup_reviewers) }
      end

      context 'when not command' do
        it { is_expected.not_to route('reviewer http://www.example.com/').to(:lookup_reviewers) }
      end
    end
  end

  describe 'integration' do
    subject { replies.last }

    context 'with non http(s) URL' do
      before { send_command('reviewer ftp://github.com/hyone/test1/pull/3') }
      it { is_expected.to eq 'Error: "ftp://github.com/hyone/test1/pull/3" is not github pullrequest URL.' }
    end

    context 'with non pullrequest URL' do
      before { send_command('reviewer https://github.com/hyone/test1/pul') }
      it { is_expected.to eq 'Error: "https://github.com/hyone/test1/pul" is not github pullrequest URL.' }
    end

    context 'with non existing pullrequest' do
      before do
        VCR.use_cassette('hyone/test1/pull/9999') do
          send_command('reviewer https://github.com/hyone/test1/pull/9999')
        end
      end

      it { is_expected.to include '404 - Not Found' }
    end

    context 'with valid pullrequest' do
      before do
        # mock `write_pr_comment` method
        allow_any_instance_of(Lita::Handlers::ReviewerLottoCheating).to \
          receive(:write_pr_comment).and_return(:nil)
        # mock `choice_reviewers` method
        allow_any_instance_of(Lita::Handlers::ReviewerLottoCheating).to \
          receive(:select_reviewers).and_return(['foo', 'bar'])

        VCR.use_cassette('hyone/test1/pull/3') do
          send_command('reviewer https://github.com/hyone/test1/pull/3')
        end
      end

      it { is_expected.to eq '@foo and @bar are assigned as the reviewers for https://github.com/hyone/test1/pull/3!!' }

      context 'and send same reviewer command again' do
        before do
          VCR.use_cassette('hyone/test1/pull/3') do
            send_command('reviewer https://github.com/hyone/test1/pull/3')
          end
        end

        it { is_expected.to eq 'https://github.com/hyone/test1/pull/3 has already assigned to reviewers.' }
      end
    end
  end
end

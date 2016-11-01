# frozen_string_literal: true

require 'spec_helper'
require 'lita/handlers/reviewer/models/user'

describe Lita::Handlers::Reviewer::User do
  before do
    described_class.init(redis: Lita.redis)
  end

  let(:user) do
    described_class.new(name: 'test', level: 1, working_days: [1, 2, 3])
  end
  subject { user.send(:key, *arguments) }

  describe '#key' do
    context 'with "field"' do
      let(:arguments) { ['field'] }
      it { is_expected.to eq 'users:test:field' }
    end

    context 'without arguments' do
      let(:arguments) { nil }
      it { is_expected.to eq 'users:test' }
    end
  end
end

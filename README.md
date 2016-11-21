# lita-reviewer-lotto-cheating

This handler checks pullrequests on specified github repos and when it finds them need to review, select reviewers for it by review counts before and lotto, and then notice to us.

## Installation

Add lita-reviewer-lotto-cheating to your Lita instance's Gemfile:

``` ruby
gem "lita-reviewer-lotto-cheating"
```

## Preparation

### Get github access token

generate access token on github form [here](https://github.com/settings/tokens/new) with following scopes:

- [ ] repo (check it if you want also to access private repositories)
  - [x] repo:status
  - [x] public_repo

## Configuration

`lita_config.rb` :

```ruby
Lita.configure do |config|
  ...

  config.handlers.reviewer_lotto_cheating.github_access_token = ENV['GITHUB_ACCESS_TOKEN']

  # duration time (second) from now, during which we calculate review count
  # of each user for selecting reviewers
  config.handlers.reviewer_lotto_cheating.reviewer_count_duration = 60 * 60 * 24
  # it can also be specified by using `ActiveSupport::Duration`.
  # config.handlers.reviewer_lotto_cheating.reviewer_count_duration = 1.month

  # repotistories from which we get pullrequests for selecting reviewers
  config.handlers.reviewer_lotto_cheating.repositories = [
    # fetch only open pullrequests by tagged with 'レビュアー募集中' from 'foo/repo1'
    {
      name: 'foo/repo1',
      labels: ['レビュアー募集中']
    },
    # fetch all open pullrequests from 'foo/repo2'
    'foo/repo2'
  ]

  # chat tareget that this plugin responses
  config.handlers.reviewer_lotto_cheating.chat_target = {
    room: '#general'
  }

  ...
end
```

## Usage

### Run on development environment
```sh
$ bundle install
$ bundle exec lita
```

### Chat commands

#### lita reviewer

    lita reviewer GITHUB_PR_URL

Choice 2 reviewers for `GITHUB_PR_URL`

### Chat Admin commands

#### lita reviewer list

    lita reviewer list

List current reviewer candidates

#### lita reviewer add

    lita reviewer add USERNAME [-l | --level NUMBER] [-w | --working_days COMMA_SEPARATED_NUMBERS]

Add `USERNAME` to reviewer candidates

Options:

- `-l` , `--level` : specify reviewer level
  ( e.g. `--level 3` )
- `-w` , `--working_days` : specify working days by comma separated numbers (0-6 Sunday is 0)
  ( e.g. `--working_days 1,2,3,4,5` )

#### lita reviewer update

    lita reviewer update USERNAME [-l | --level NUMBER] [-w | --working_days COMMA_SEPARATED_NUMBERS]

Update `USERNAME` properties

Options:

- `-l` , `--level` : specify reviewer level
  ( e.g. `--level 3` )
- `-w` , `--working_days` : specify working days by comma separated numbers (0-6 Sunday is 0)
  ( e.g. `--working_days 1,2,3,4,5` )

#### lita reviewer delete

    lita reviewer delete USERNAME

Delete `USERNAME` from reviewer candidates

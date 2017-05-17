# lita-reviewer-lotto-cheating

[![CircleCI](https://circleci.com/gh/ClinicalPlatform/lita-reviewer-lotto-cheating.svg?style=svg)](https://circleci.com/gh/ClinicalPlatform/lita-reviewer-lotto-cheating)

This handler checks pullrequests on github repos specified and when it finds them need to review, assign reviewers for them based on both review counts of each user before and a little bit of lotto, and then notice to us.

## Installation

Add lita-reviewer-lotto-cheating to your Lita instance's Gemfile:

``` ruby
gem "lita-reviewer-lotto-cheating"
```

## Preparation

### Get github access token

generate access token on github form [here](https://github.com/settings/tokens/new) with following scopes:

- [ ] repo (check this if you want also to access private repositories)
  - [x] repo:status
  - [x] public_repo

## Configuration

### Required attributes

* `github_access_token` (String)

   access token for Github API

* `repositories` (Array)

   repotistories from which we get pullrequests for selecting reviewers

### Optional attributes

* `reviewer_count_duration` (Fixnum or ActiveSupport::Duration)

   duration time (second) from now, during which we calculate review count
   of each user for selecting reviewers

* `random_weight` (Fixnum in 0..100)

   percentage number of the randomness factor in the reviwers selection factors

* `chat_target` (Object)

   chat tareget that this plugin responses

### Example

`lita_config.rb` :

```ruby
Lita.configure do |config|
  config.handlers.reviewer_lotto_cheating.github_access_token = ENV['GITHUB_ACCESS_TOKEN']

  config.handlers.reviewer_lotto_cheating.repositories = [
    # fetch open pullrequests by tagged with 'レビュアー募集中' from 'foo/repo1'
    {
      name: 'foo/repo1',
      labels: ['レビュアー募集中']
    },
    # fetch all open pullrequests from 'foo/repo2'
    'foo/repo2'
  ]

  config.handlers.reviewer_lotto_cheating.reviewer_count_duration = 60 * 60 * 24
  # it can also be specified by using `ActiveSupport::Duration`.
  # config.handlers.reviewer_lotto_cheating.reviewer_count_duration = 1.month

  config.handlers.reviewer_lotto_cheating.chat_target = {
    room: '#general'
  }
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

Choice 2 reviewers for `GITHUB_PR_URL`.
And then notice them to us on chat, `GITHUB_PR_URL` comment and status checker

Options:

- `-f` , `--force`

  force to assign reviewers even though GITHUB_PR_URL has been alraedy assigned them to.

#### lita reviewer list

    lita reviewer list

Display all reviewer candidates

#### lita reviewer add

    lita reviewer add USERNAME [-l | --level NUMBER] [-w | --working_days COMMA_SEPARATED_NUMBERS]

Add `USERNAME` to reviewer candidates

Options:

- `-l` , `--level` ( e.g. `--level 2` )

  specify reviewer level, which is used to divide the user into junior reviewer group and senior reviewer group.

  - a user whose level is greater than or equal to `2` is senior reviewer.
  - a user whose level is less than `2` is junior reviewer.

  one user from each group is selected as a reviewer.

- `-w` , `--working_days` ( e.g. `--working_days 1,2,3,4,5` )

  specify working days by comma separated numbers ( `0-6` Sunday is `0` )
  reviewers are selected only from reviewer candidates that today is their working day

#### lita reviewer delete

    lita reviewer delete USERNAME

Delete `USERNAME` from reviewer candidates

### Tips

#### Reset users information

```sh
$ redis-cli KEYS "lita:handlers:reviewer_lotto_cheating:users*" | xargs redis-cli DEL
```

#### Reset pullrequest histories that are assigned to reviewers

```sh
$ redis-cli KEYS "lita:handlers:reviewer_lotto_cheating:pullrequests*" | xargs redis-cli DEL
```

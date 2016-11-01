Lita.configure do |config|
  config.robot.name = 'lita'
  config.robot.log_level = :debug

  config.robot.adapter = :shell
  # To omit prefix 'lita' from commands
  config.adapters.shell.private_chat = true

  config.handlers.reviewer_lotto_cheating.github_access_token = ENV['GITHUB_ACCESS_TOKEN']

  # duration in which we calculate review count by each user
  config.handlers.reviewer_lotto_cheating.reviewer_count_duration = 300

  config.handlers.reviewer_lotto_cheating.repositories = [
    # fetch only open pullrequests by tagged with 'レビュアー募集中' from 'foo/repo1'
    {
      name: 'hyone/test1',
      labels: ['レビュアー募集中']
    },
    # fetch all open pullrequests from 'foo/repo2'
    'hyone/test2'
  ]

  # default chat tareget that this plugin responses
  config.handlers.reviewer_lotto_cheating.chat_target = {
    room: '#general'
  }

  config.redis[:url] = ENV['REDISTOGO_URL']
  config.http.port = ENV['PORT']
end

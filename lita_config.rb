Lita.configure do |config|
  config.robot.name = 'lita'
  config.robot.log_level = :debug

  config.robot.adapter = :shell
  # To omit prefix 'lita' from commands
  config.adapters.shell.private_chat = true

  config.handlers.reviewer.github_access_token = ENV['GITHUB_ACCESS_TOKEN']
  config.handlers.reviewer.reviewer_count_duration = 300
  config.handlers.reviewer.repositories = [
    {
      name: 'hyone/test1',
      labels: ['レビュアー募集中']
    },
    'hyone/test2'
  ]
  config.handlers.reviewer.default_chat_target = {
    room: '#general'
  }

  config.redis[:url] = ENV['REDISTOGO_URL']
  config.http.port = ENV['PORT']
end

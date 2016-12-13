# Lita::Handler::Common モジュールの translate メソッドは、プラグインの名前空間を決める
# namespace メソッドに依存しているため、単体でこのモジュールを include して translate
# メソッドを使おうとすると、各クラスで `namespace 'reviewer_lotto_cheating'` という宣言が
# 必要になってしまい、使用上不便なので、 Lita::Handler を継承したクラス以外からでも手軽に
# 使えるように、専用の translate メソッドを定義しておく。
#
# see also: https://github.com/litaio/lita/blob/ea737008dfeb5faa5f77f6a794b6b2738592aa23/lib/lita/handler/common.rb#L35-L37
module Lita::Handlers::ReviewerLottoCheating
  module Translatable
    def translate(key, hash = {})
      I18n.translate("lita.handlers.reviewer_lotto_cheating.#{key}", hash)
    end

    alias t translate
  end
end
